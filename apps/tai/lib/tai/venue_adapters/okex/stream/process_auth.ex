defmodule Tai.VenueAdapters.OkEx.Stream.ProcessAuth do
  use GenServer
  alias Tai.Events
  alias Tai.VenueAdapters.OkEx.{ClientId, Stream}

  defmodule State do
    @type venue_id :: Tai.Venues.Adapter.venue_id()
    @type t :: %State{venue: atom, tasks: map}

    @enforce_keys ~w(venue tasks)a
    defstruct ~w(venue tasks)a
  end

  @type venue_id :: Tai.Venues.Adapter.venue_id()
  @type state :: State.t()

  def start_link(venue: venue) do
    state = %State{venue: venue, tasks: %{}}
    name = venue |> to_name()
    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec init(state) :: {:ok, state}
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  @product_types ["swap/order", "futures/order"]
  def handle_cast(
        {%{"table" => table, "data" => orders}, received_at},
        state
      )
      when table in @product_types do
    new_tasks =
      orders
      |> Enum.map(fn %{"client_oid" => venue_client_id} = venue_order ->
        Task.async(fn ->
          venue_client_id
          |> ClientId.from_base32()
          |> Stream.UpdateOrder.update(venue_order, received_at)
        end)
      end)
      |> Enum.reduce(%{}, fn t, acc -> Map.put(acc, t.ref, true) end)
      |> Map.merge(state.tasks)

    new_state = state |> Map.put(:tasks, new_tasks)

    {:noreply, new_state}
  end

  def handle_cast({msg, received_at}, state) do
    %Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: received_at
    }
    |> Events.warn()

    {:noreply, state}
  end

  def handle_info({_reference, response}, state) do
    response |> parse_task_result()
    {:noreply, state}
  end

  def handle_info({:DOWN, reference, :process, _pid, :normal}, state) do
    new_tasks = state.tasks |> Map.delete(reference)
    new_state = state |> Map.put(:tasks, new_tasks)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, reference, :process, _pid, reason}, state) do
    %Events.StreamError{
      venue_id: state.venue,
      reason: reason
    }
    |> Events.error()

    new_tasks = state.tasks |> Map.delete(reference)
    new_state = state |> Map.put(:tasks, new_tasks)
    {:noreply, new_state}
  end

  def handle_info({:EXIT, _, _}, state), do: {:noreply, state}

  defp parse_task_result(:ok), do: :ok

  defp parse_task_result({:ok, _}), do: :ok

  defp parse_task_result({:error, {:invalid_status, was, required, %action_name{} = action}}) do
    Tai.Events.warn(%Tai.Events.OrderUpdateInvalidStatus{
      was: was,
      required: required,
      client_id: action.client_id,
      action: action_name
    })
  end

  defp parse_task_result({:error, {:not_found, %action_name{} = action}}) do
    Tai.Events.warn(%Tai.Events.OrderUpdateNotFound{
      client_id: action.client_id,
      action: action_name
    })
  end
end
