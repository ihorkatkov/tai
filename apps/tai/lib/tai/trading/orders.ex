defmodule Tai.Trading.Orders do
  alias Tai.Trading.{Order, Orders, OrderSubmissions}

  @type submission :: OrderSubmissions.Factory.submission()
  @type order :: Order.t()
  @type create_response :: Orders.Create.response()
  @type amend_attrs :: Orders.Amend.attrs()
  @type amend_response :: Orders.Amend.response()
  @type cancel_response :: Orders.Cancel.response()

  @spec create(submission) :: create_response
  defdelegate create(submission), to: Orders.Create

  @spec amend(order, amend_attrs, module) :: amend_response
  defdelegate amend(order, attrs, provider), to: Orders.Amend

  @spec amend(order, amend_attrs) :: amend_response
  defdelegate amend(order, attrs), to: Orders.Amend

  @spec cancel(order, module) :: cancel_response
  defdelegate cancel(order, provider), to: Orders.Cancel

  @spec cancel(order) :: cancel_response
  defdelegate cancel(order), to: Orders.Cancel
end
