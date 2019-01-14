defmodule Tai.VenueAdapters.Binance do
  @behaviour Tai.Venues.Adapter

  def stream_supervisor, do: Tai.Venues.NullStreamSupervisor

  def order_book_feed, do: Tai.VenueAdapters.Binance.OrderBookFeed

  defdelegate products(venue_id), to: Tai.VenueAdapters.Binance.Products

  defdelegate asset_balances(venue_id, account_id, credentials),
    to: Tai.VenueAdapters.Binance.AssetBalances

  defdelegate maker_taker_fees(venue_id, account_id, credentials),
    to: Tai.VenueAdapters.Binance.MakerTakerFees

  def create_order(%Tai.Trading.Order{} = _order, _credentials) do
    {:error, :not_implemented}
  end

  def amend_order(_venue_order_id, _attrs, _credentials) do
    {:error, :not_implemented}
  end

  def amend_all_orders(_orders_with_attrs, _credentials) do
    {:error, :not_implemented}
  end

  def cancel_order(_venue_order_id, _credentials) do
    {:error, :not_implemented}
  end
end
