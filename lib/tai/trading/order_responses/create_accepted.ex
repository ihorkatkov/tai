defmodule Tai.Trading.OrderResponses.CreateAccepted do
  @moduledoc """
  Returned from venue adapters when accepted for creation. Updates to the order 
  will be received from the stream.
  """

  @type t :: %Tai.Trading.OrderResponses.CreateAccepted{
          id: Tai.Trading.Order.venue_order_id(),
          received_at: DateTime.t(),
          venue_timestamp: DateTime.t() | nil
        }

  @enforce_keys ~w(id received_at)a
  defstruct ~w(id received_at venue_timestamp)a
end
