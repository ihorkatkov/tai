defmodule Tai.Venues.Adapters.CreateOrderGtcTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    on_exit(fn ->
      Application.stop(:tai)
    end)

    {:ok, _} = Application.ensure_all_started(:tai)
    HTTPoison.start()
  end

  @sides [:buy, :sell]

  @open_test_adapters Tai.TestSupport.Helpers.test_venue_adapters_create_order_gtc_open()
  @open_test_adapters
  |> Enum.map(fn {_, adapter} ->
    @adapter adapter

    @sides
    |> Enum.each(fn side ->
      @side side

      test "#{adapter.id} #{side} limit filled open" do
        order = build_order(@adapter.id, @side, :gtc, post_only: false, action: :filled)

        use_cassette "venue_adapters/shared/orders/#{@adapter.id}/#{@side}_limit_gtc_filled" do
          assert {:ok, order_response} = Tai.Venue.create_order(order, @open_test_adapters)

          assert order_response.id != nil
          assert %Decimal{} = order_response.original_size
          assert %Decimal{} = order_response.cumulative_qty
          assert order_response.leaves_qty == Decimal.new(0)
          assert order_response.cumulative_qty == order_response.original_size
          assert order_response.status == :filled
          assert %DateTime{} = order_response.venue_timestamp
        end
      end

      test "#{adapter.id} #{side} limit partially filled open" do
        order = build_order(@adapter.id, @side, :gtc, post_only: false, action: :partially_filled)

        use_cassette "venue_adapters/shared/orders/#{@adapter.id}/#{@side}_limit_gtc_partially_filled" do
          assert {:ok, order_response} = Tai.Venue.create_order(order, @open_test_adapters)

          assert order_response.id != nil
          assert %Decimal{} = order_response.original_size
          assert %Decimal{} = order_response.leaves_qty
          assert order_response.cumulative_qty != order_response.original_size
          assert order_response.cumulative_qty != Decimal.new(0)
          assert order_response.leaves_qty != Decimal.new(0)
          assert order_response.leaves_qty != order_response.original_size
          assert order_response.status == :open
          assert %DateTime{} = order_response.venue_timestamp
        end
      end

      test "#{adapter.id} #{side} limit unfilled open" do
        order = build_order(@adapter.id, @side, :gtc, post_only: false, action: :unfilled)

        use_cassette "venue_adapters/shared/orders/#{@adapter.id}/#{@side}_limit_gtc_unfilled" do
          assert {:ok, order_response} = Tai.Venue.create_order(order, @open_test_adapters)

          assert order_response.id != nil
          assert order_response.status == :open
          assert order_response.leaves_qty == order_response.original_size
          assert order_response.cumulative_qty == Decimal.new(0)
          assert %DateTime{} = order_response.venue_timestamp
        end
      end
    end)
  end)

  @accepted_test_adapters Tai.TestSupport.Helpers.test_venue_adapters_create_order_gtc_accepted()
  @accepted_test_adapters
  |> Enum.map(fn {_, adapter} ->
    @adapter adapter

    @sides
    |> Enum.each(fn side ->
      @side side

      test "#{adapter.id} #{side} limit unfilled accepted" do
        order = build_order(@adapter.id, @side, :gtc, post_only: false, action: :unfilled)

        use_cassette "venue_adapters/shared/orders/#{@adapter.id}/#{@side}_limit_gtc_unfilled" do
          assert {:ok, order_response} = Tai.Venue.create_order(order, @accepted_test_adapters)

          assert %Tai.Trading.OrderResponses.CreateAccepted{} = order_response
          assert order_response.id != nil
        end
      end
    end)
  end)

  defp build_order(venue_id, side, time_in_force, opts) do
    action = Keyword.fetch!(opts, :action)
    post_only = Keyword.get(opts, :post_only, false)

    struct(Tai.Trading.Order, %{
      client_id: Ecto.UUID.generate(),
      venue_id: venue_id,
      account_id: :main,
      product_symbol: venue_id |> product_symbol,
      product_type: venue_id |> product_type,
      side: side,
      price: venue_id |> price(side, time_in_force, action),
      qty: venue_id |> qty(side, time_in_force, action),
      type: :limit,
      time_in_force: time_in_force,
      post_only: post_only
    })
  end

  defp product_symbol(:bitmex), do: :xbth19
  defp product_symbol(:okex_futures), do: :eth_usd_190628
  defp product_symbol(:okex_swap), do: :eth_usd_swap
  defp product_symbol(_), do: :ltc_btc

  defp product_type(:okex_swap), do: :swap
  defp product_type(_), do: :future

  defp price(:bitmex, :buy, :gtc, :filled), do: Decimal.new("4455")
  defp price(:bitmex, :sell, :gtc, :filled), do: Decimal.new("3767")
  defp price(:bitmex, :buy, :gtc, :unfilled), do: Decimal.new("100.5")
  defp price(:bitmex, :sell, :gtc, :unfilled), do: Decimal.new("50000.5")
  defp price(:okex_futures, :buy, :gtc, :unfilled), do: Decimal.new("70.5")
  defp price(:okex_futures, :sell, :gtc, :unfilled), do: Decimal.new("290.5")
  defp price(:okex_swap, :buy, :gtc, :unfilled), do: Decimal.new("70.5")
  defp price(:okex_swap, :sell, :gtc, :unfilled), do: Decimal.new("290.5")
  defp price(:bitmex, :buy, :gtc, :partially_filled), do: Decimal.new("4130")
  defp price(:bitmex, :sell, :gtc, :partially_filled), do: Decimal.new("3795.5")
  defp price(_, :buy, _, _), do: Decimal.new("0.007")
  defp price(_, :sell, _, _), do: Decimal.new("0.1")

  defp qty(:bitmex, :buy, :gtc, :filled), do: Decimal.new(150)
  defp qty(:bitmex, :sell, :gtc, :filled), do: Decimal.new(10)
  defp qty(:bitmex, :buy, :gtc, :partially_filled), do: Decimal.new(100)
  defp qty(:bitmex, :sell, :gtc, :partially_filled), do: Decimal.new(100)
  defp qty(:bitmex, _, :gtc, :insufficient_balance), do: Decimal.new(1_000_000)
  defp qty(:bitmex, :buy, _, _), do: Decimal.new(1)
  defp qty(:bitmex, :sell, _, _), do: Decimal.new(1)
  defp qty(:okex_futures, :buy, _, _), do: Decimal.new(1)
  defp qty(:okex_futures, :sell, _, _), do: Decimal.new(1)
  defp qty(:okex_swap, :buy, _, _), do: Decimal.new(1)
  defp qty(:okex_swap, :sell, _, _), do: Decimal.new(1)
  defp qty(_, _, :gtc, :insufficient_balance), do: Decimal.new(1_000)
  defp qty(_, :buy, _, _), do: Decimal.new("0.2")
  defp qty(_, :sell, _, _), do: Decimal.new("0.1")
end
