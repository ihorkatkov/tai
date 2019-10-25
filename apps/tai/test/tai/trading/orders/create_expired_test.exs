defmodule Tai.Trading.Orders.CreateExpiredTest do
  use ExUnit.Case, async: false
  alias Tai.TestSupport.Mocks
  alias Tai.Trading.{Order, Orders, OrderSubmissions}

  setup do
    on_exit(fn ->
      :ok = Application.stop(:tai)
    end)

    start_supervised!(Mocks.Server)
    {:ok, _} = Application.ensure_all_started(:tai)
    :ok
  end

  @venue_order_id "df8e6bd0-a40a-42fb-8fea-b33ef4e34f14"

  [{:buy, OrderSubmissions.BuyLimitIoc}, {:sell, OrderSubmissions.SellLimitIoc}]
  |> Enum.each(fn {side, submission_type} ->
    @submission_type submission_type

    test "#{side} updates the relevant attributes" do
      original_qty = Decimal.new(10)
      cumulative_qty = Decimal.new(3)

      submission =
        Support.OrderSubmissions.build_with_callback(@submission_type, %{qty: original_qty})

      Mocks.Responses.Orders.ImmediateOrCancel.expired(@venue_order_id, submission, %{
        cumulative_qty: cumulative_qty
      })

      {:ok, _} = Orders.create(submission)

      assert_receive {
        :order_updated,
        nil,
        %Order{status: :enqueued}
      }

      assert_receive {
        :order_updated,
        %Order{status: :enqueued},
        %Order{status: :expired} = expired_order
      }

      assert expired_order.venue_order_id == @venue_order_id
      assert expired_order.leaves_qty == Decimal.new(0)
      assert expired_order.cumulative_qty == cumulative_qty
      assert expired_order.qty == original_qty
      assert %DateTime{} = expired_order.last_venue_timestamp
    end
  end)
end
