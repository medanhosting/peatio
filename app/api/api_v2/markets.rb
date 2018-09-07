# encoding: UTF-8
# frozen_string_literal: true

module APIv2
  class Markets < Grape::API

    desc 'Get all available markets.'
    get "/markets" do
      present Market.enabled.ordered, with: APIv2::Entities::Market
    end

    desc 'Get config data for trading-ui.'
    get "/markets/:market" do
      market        = current_market
      markets       = Market.enabled.ordered
      market_groups = markets.map(&:ask_unit).uniq

      member = get_member

      result = trading_variables(member)
      result.bids   = market.bids
      result.asks   = market.asks
      result.trades = market.trades

      if member
        orders_wait = member.orders.includes(:market).where(market_id: market).with_state(:wait)
        trades_done = Trade.includes(:market).for_member(market.id, current_user, limit: 100, order: 'id desc')
        result.my_trades = trades_done.map(&:for_notify)
        result.my_orders = *([orders_wait] + %i[id at market kind price state volume origin_volume])
      end

      accounts = member&.accounts&.enabled&.includes(:currency)&.map do |x|
        { id:         x.id,
          locked:     x.locked,
          amount:     x.amount,
          currency:   {
              code:     x.currency.code,
              symbol:   x.currency.symbol,
              type:     x.currency.type,
              icon_url: currency_icon_url(x.currency) } }
      end

      { current_market: market.as_json,
        gon_variables:  result.to_h,
        market_groups:  market_groups,
        currencies:     Currency.enabled.order(id: :asc).map { |c| { code: c.code, type: c.type } },
        current_member: member,
        markets:        markets.map { |m| m.as_json.merge!(ticker: Global[m].ticker) },
        my_accounts:    accounts,
        csrf_token:     'hghsdf'
      }
    end
  end
end
