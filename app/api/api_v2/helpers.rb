# encoding: UTF-8
# frozen_string_literal: true

module APIv2
  module Helpers
    extend Memoist

    def authenticate!
      current_user or raise Peatio::Auth::Error
    end

    def get_member
      current_user rescue nil
    end

    def currency_icon_url(currency)
      if currency.icon_url.blank?
        "assets/#{currency.code}.svg"
      else
        currency.icon_url
      end
    end

    def deposits_must_be_permitted!
      if current_user.level < ENV.fetch('MINIMUM_MEMBER_LEVEL_FOR_DEPOSIT').to_i
        raise Error.new(text: 'Please, pass the corresponding verification steps to deposit funds.', status: 401)
      end
    end

    def withdraws_must_be_permitted!
      if current_user.level < ENV.fetch('MINIMUM_MEMBER_LEVEL_FOR_WITHDRAW').to_i
        raise Error.new(text: 'Please, pass the corresponding verification steps to withdraw funds.', status: 401)
      end
    end

    def trading_must_be_permitted!
      if current_user.level < ENV.fetch('MINIMUM_MEMBER_LEVEL_FOR_TRADING').to_i
        raise Error.new(text: 'Please, pass the corresponding verification steps to enable trading.', status: 401)
      end
    end

    def redis
      KlineDB.redis
    end
    memoize :redis

    def current_user
      # JWT authentication provides member email.
      if env.key?('api_v2.authentic_member_email')
        Member.find_by_email(env['api_v2.authentic_member_email'])
      end
    end
    memoize :current_user

    def current_market
      Market.enabled.find_by_id(params[:market])
    end
    memoize :current_market

    def time_to
      params[:timestamp].present? ? Time.at(params[:timestamp]) : nil
    end

    def build_order(attrs)
      (attrs[:side] == 'sell' ? OrderAsk : OrderBid).new \
        state:         ::Order::WAIT,
        member:        current_user,
        ask:           current_market&.base_unit,
        bid:           current_market&.quote_unit,
        market:        current_market,
        ord_type:      attrs[:ord_type] || 'limit',
        price:         attrs[:price],
        volume:        attrs[:volume],
        origin_volume: attrs[:volume]
    end

    def create_order(attrs)
      order = build_order(attrs)
      Ordering.new(order).submit
      order
    rescue Account::AccountError => e
      report_exception_to_screen(e)
      raise CreateOrderAccountError, e.inspect
    rescue => e
      report_exception_to_screen(e)
      raise CreateOrderError, e.inspect
    end

    def create_orders(multi_attrs)
      orders = multi_attrs.map(&method(:build_order))
      Ordering.new(orders).submit
      orders
    rescue => e
      report_exception_to_screen(e)
      raise CreateOrderError, e.inspect
    end

    def order_param
      params[:order_by].downcase == 'asc' ? 'id asc' : 'id desc'
    end

    def format_ticker(ticker)
      { at: ticker[:at],
        ticker: {
          buy: ticker[:buy],
          sell: ticker[:sell],
          low: ticker[:low],
          high: ticker[:high],
          last: ticker[:last],
          vol: ticker[:volume]
        }
      }
    end

    def get_k_json
      key = "peatio:#{params[:market]}:k:#{params[:period]}"

      if params[:time_from]
        ts_json = redis.lindex(key, 0)
        return [] if ts_json.blank?
        ts = JSON.parse(ts_json).first
        offset = (params[:time_from] - ts) / 60 / params[:period]
        offset = 0 if offset < 0
        limit_offset = offset + params[:limit] - 1
        if params[:time_to]
          end_offset = (params[:time_to] - ts) / 60 / params[:period]
          end_offset = 0 if end_offset < 0
          limit_offset = end_offset if end_offset < limit_offset
        end
        JSON.parse('[%s]' % redis.lrange(key, offset, limit_offset).join(','))
      else
        length = redis.llen(key)
        offset = [length - params[:limit], 0].max
        JSON.parse('[%s]' % redis.lrange(key, offset, -1).join(','))
      end
    end

    def trading_variables(member)
      gon = OpenStruct.new
      gon.environment = Rails.env
      gon.local = I18n.locale
      gon.market = current_market.attributes
      gon.ticker = current_market.ticker
      gon.markets = Market.enabled.each_with_object({}) { |market, memo| memo[market.id] = market.as_json }
      gon.host = request.base_url
      gon.pusher = {
          key:       ENV.fetch('PUSHER_CLIENT_KEY'),
          wsHost:    ENV.fetch('PUSHER_CLIENT_WS_HOST'),
          httpHost:  ENV['PUSHER_CLIENT_HTTP_HOST'],
          wsPort:    ENV.fetch('PUSHER_CLIENT_WS_PORT'),
          wssPort:   ENV.fetch('PUSHER_CLIENT_WSS_PORT'),
      }.reject { |k, v| v.blank? }
                       .merge(encrypted: ENV.fetch('PUSHER_CLIENT_ENCRYPTED').present?)

      gon.clipboard = {
          :click => I18n.t('actions.clipboard.click'),
          :done => I18n.t('actions.clipboard.done')
      }

      gon.i18n = {
          ask: I18n.t('gon.ask'),
          bid: I18n.t('gon.bid'),
          cancel: I18n.t('actions.cancel'),
          latest_trade: I18n.t('private.markets.order_book.latest_trade'),
          switch: {
              notification: I18n.t('private.markets.settings.notification'),
              sound: I18n.t('private.markets.settings.sound')
          },
          notification: {
              title: I18n.t('gon.notification.title'),
              enabled: I18n.t('gon.notification.enabled'),
              new_trade: I18n.t('gon.notification.new_trade')
          },
          time: {
              minute: I18n.t('chart.minute'),
              hour: I18n.t('chart.hour'),
              day: I18n.t('chart.day'),
              week: I18n.t('chart.week'),
              month: I18n.t('chart.month'),
              year: I18n.t('chart.year')
          },
          chart: {
              price: I18n.t('chart.price'),
              volume: I18n.t('chart.volume'),
              open: I18n.t('chart.open'),
              high: I18n.t('chart.high'),
              low: I18n.t('chart.low'),
              close: I18n.t('chart.close'),
              candlestick: I18n.t('chart.candlestick'),
              line: I18n.t('chart.line'),
              zoom: I18n.t('chart.zoom'),
              depth: I18n.t('chart.depth'),
              depth_title: I18n.t('chart.depth_title')
          },
          place_order: {
              confirm_submit: I18n.t('private.markets.show.confirm'),
              confirm_cancel: I18n.t('private.markets.show.cancel_confirm'),
              price: I18n.t('private.markets.place_order.price'),
              volume: I18n.t('private.markets.place_order.amount'),
              sum: I18n.t('private.markets.place_order.total'),
              price_high: I18n.t('private.markets.place_order.price_high'),
              price_low: I18n.t('private.markets.place_order.price_low'),
              full_bid: I18n.t('private.markets.place_order.full_bid'),
              full_ask: I18n.t('private.markets.place_order.full_ask')
          },
          trade_state: {
              new: I18n.t('private.markets.trade_state.new'),
              partial: I18n.t('private.markets.trade_state.partial')
          }
      }

      gon.currencies = Currency.enabled.inject({}) do |memo, currency|
        memo[currency.code] = {
            code: currency.code,
            symbol: currency.symbol,
            isCoin: currency.coin?
        }
        memo
      end
      gon.display_currency = ENV.fetch('DISPLAY_CURRENCY')
      gon.fiat_currencies = Currency.enabled.ordered.fiats.codes

      gon.tickers = {}
      Market.enabled.each do |market|
        gon.tickers[market.id] = market.unit_info.merge(Global[market.id].ticker)
      end

      if member
        gon.user = { sn: member.sn }
        gon.accounts = member.accounts.enabled.includes(:currency).inject({}) do |memo, account|
          memo[account.currency.code] = {
              currency: account.currency.code,
              balance: account.balance,
              locked: account.locked
          } if account.currency.try(:enabled)
          memo
        end
      end

      gon.bank_details_html = ENV['BANK_DETAILS_HTML']
      gon.ranger_host = ENV["RANGER_HOST"] || "0.0.0.0"
      gon.ranger_port = ENV["RANGER_PORT"] || "8081"
      gon
    end
  end
end
