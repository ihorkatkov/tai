defmodule Tai.Exchanges.Product do
  @type t :: %Tai.Exchanges.Product{
          exchange_id: atom,
          symbol: atom,
          exchange_symbol: String.t(),
          status: atom,
          min_notional: Decimal.t(),
          min_price: Decimal.t(),
          min_size: Decimal.t(),
          max_price: Decimal.t() | nil,
          max_size: Decimal.t() | nil,
          price_increment: Decimal.t() | nil,
          size_increment: Decimal.t() | nil
        }

  @enforce_keys [
    :exchange_id,
    :symbol,
    :exchange_symbol,
    :status,
    :min_notional,
    :min_price,
    :min_size
  ]
  defstruct [
    :exchange_id,
    :symbol,
    :exchange_symbol,
    :status,
    :min_notional,
    :min_price,
    :min_size,
    :max_size,
    :max_price,
    :price_increment,
    :size_increment
  ]
end
