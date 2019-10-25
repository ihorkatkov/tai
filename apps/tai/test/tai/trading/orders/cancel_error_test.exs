defmodule Tai.Trading.Orders.CancelErrorTest do
  use ExUnit.Case, async: false
  alias Tai.Trading.OrderSubmissions.SellLimitGtc
  alias Tai.Trading.{Order, Orders, OrderStore}
  alias Tai.Events
  alias Tai.TestSupport.Mocks

  defmodule TestFilledProvider do
    @venue_order_id "df8e6bd0-a40a-42fb-8fea-b33ef4e34f14"
    @venue :test_exchange_a
    @account :main

    def update(%OrderStore.Actions.PendCancel{} = action) do
      open_order =
        struct(Order,
          client_id: action.client_id,
          venue_order_id: @venue_order_id,
          venue_id: @venue,
          account_id: @account,
          status: :open
        )

      pending_cancel_order =
        struct(Order,
          client_id: open_order.client_id,
          venue_order_id: open_order.venue_order_id,
          venue_id: open_order.venue_id,
          account_id: open_order.account_id,
          status: :pending_cancel
        )

      {:ok, {open_order, pending_cancel_order}}
    end

    def update(%OrderStore.Actions.Cancel{} = action) do
      {:error, {:invalid_status, :filled, [:cancel_required_a, :cancel_required_b], action}}
    end
  end

  @venue_order_id "df8e6bd0-a40a-42fb-8fea-b33ef4e34f14"

  setup do
    on_exit(fn ->
      Application.stop(:tai)
    end)

    start_supervised!(Mocks.Server)
    {:ok, _} = Application.ensure_all_started(:tai)

    submission =
      Support.OrderSubmissions.build_with_callback(
        SellLimitGtc,
        %{order_updated_callback: self()}
      )

    {:ok, %{submission: submission}}
  end

  @venue_order_id "df8e6bd0-a40a-42fb-8fea-b33ef4e34f14"

  describe "with an invalid pending cancel status" do
    setup(%{submission: submission}) do
      {:ok, _order} = Orders.create(submission)
      assert_receive {:order_updated, _, %Order{status: :create_error} = error_order}

      {:ok, %{order: error_order}}
    end

    test "returns an error", %{order: order} do
      assert {:error, reason} = Orders.cancel(order)
      assert {:invalid_status, :create_error, required_status, action} = reason
      assert required_status == [:amend_error, :cancel_error, :open, :partially_filled]
      assert %OrderStore.Actions.PendCancel{} = action
    end

    test "emits an invalid status warning", %{order: order} do
      Events.firehose_subscribe()

      Orders.cancel(order)

      assert_receive {
        Tai.Event,
        %Events.OrderUpdateInvalidStatus{} = pending_cancel_invalid_event,
        :warn
      }

      assert pending_cancel_invalid_event.client_id == order.client_id
      assert pending_cancel_invalid_event.action == OrderStore.Actions.PendCancel
      assert pending_cancel_invalid_event.was == :create_error

      assert pending_cancel_invalid_event.required == [
               :amend_error,
               :cancel_error,
               :open,
               :partially_filled
             ]
    end
  end

  test "invalid cancel status emits an event" do
    open_order = struct(Order, client_id: "abc123", venue_order_id: @venue_order_id)
    Mocks.Responses.Orders.GoodTillCancel.canceled(@venue_order_id)
    Events.firehose_subscribe()

    Orders.cancel(open_order, TestFilledProvider)

    assert_receive {
      Tai.Event,
      %Events.OrderUpdateInvalidStatus{} = cancel_invalid_event,
      :warn
    }

    assert cancel_invalid_event.client_id == open_order.client_id
    assert cancel_invalid_event.action == OrderStore.Actions.Cancel
    assert cancel_invalid_event.was == :filled

    assert cancel_invalid_event.required == [
             :cancel_required_a,
             :cancel_required_b
           ]
  end

  test "venue error updates status and records the reason", %{submission: submission} do
    Mocks.Responses.Orders.GoodTillCancel.open(@venue_order_id, submission)
    {:ok, _order} = Tai.Trading.Orders.create(submission)
    assert_receive {:order_updated, _prev, %Order{status: :open} = open_order}

    assert {:ok, _} = Tai.Trading.Orders.cancel(open_order)

    assert_receive {:order_updated, _prev, %Order{status: :cancel_error} = error_order}
    assert error_order.last_received_at != open_order.last_received_at
    assert error_order.error_reason == :mock_not_found
  end

  test "rescues adapter errors", %{submission: submission} do
    Mocks.Responses.Orders.GoodTillCancel.open(@venue_order_id, submission)
    {:ok, order} = Tai.Trading.Orders.create(submission)

    assert_receive {
      :order_updated,
      %Tai.Trading.Order{status: :enqueued},
      %Tai.Trading.Order{status: :open} = open_order
    }

    Mocks.Responses.Orders.Error.cancel_raise(
      @venue_order_id,
      "Venue Adapter Cancel Raised Error"
    )

    assert {:ok, _} = Tai.Trading.Orders.cancel(order)

    assert_receive {
      :order_updated,
      %Tai.Trading.Order{status: :pending_cancel},
      %Tai.Trading.Order{status: :cancel_error} = error_order
    }

    assert {:unhandled, {error, [stack_1 | _]}} = error_order.error_reason
    assert error_order.last_received_at != open_order.last_received_at
    assert error == %RuntimeError{message: "Venue Adapter Cancel Raised Error"}
    assert {Tai.VenueAdapters.Mock, _, _, [file: _, line: _]} = stack_1
  end
end
