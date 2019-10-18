defmodule Tai.VenueAdapters.Bitmex.Stream.ProcessAuth.Messages.UpdateOrders.NewPartialFill do
  defstruct ~w(
    account
    cl_ord_id
    cum_qty
    leaves_qty
    order_id
    symbol
    timestamp
  )a
end

defimpl Tai.VenueAdapters.Bitmex.Stream.ProcessAuth.Message,
  for: Tai.VenueAdapters.Bitmex.Stream.ProcessAuth.Messages.UpdateOrders.NewPartialFill do
  alias Tai.VenueAdapters.Bitmex

  @date_format "{ISO:Extended}"

  def process(message, received_at, _state) do
    message.cl_ord_id
    |> case do
      "gtc-" <> id ->
        client_id = Bitmex.ClientId.from_base64(id)
        venue_timestamp = message.timestamp |> Timex.parse!(@date_format)
        leaves_qty = message.leaves_qty |> Decimal.cast()
        cumulative_qty = message.cum_qty |> Decimal.cast()

        %Tai.Trading.OrderStore.Actions.PassivePartialFill{
          client_id: client_id,
          cumulative_qty: cumulative_qty,
          leaves_qty: leaves_qty,
          last_received_at: received_at,
          last_venue_timestamp: venue_timestamp
        }
        |> Tai.Trading.OrderStore.update()
        |> parse_result()

      _ ->
        :ignore
    end

    :ok
  end

  defp parse_result({:ok, _}), do: :ok

  defp parse_result({:error, {:invalid_status, was, required, %action_name{} = action}}) do
    Tai.Events.warn(%Tai.Events.OrderUpdateInvalidStatus{
      was: was,
      required: required,
      client_id: action.client_id,
      action: action_name
    })
  end

  defp parse_result({:error, {:not_found, %action_name{} = action}}) do
    Tai.Events.warn(%Tai.Events.OrderUpdateNotFound{
      client_id: action.client_id,
      action: action_name
    })
  end
end
