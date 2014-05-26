class Trade < ActiveRecord::Base
  has_many :trade_results, dependent: :destroy
  belongs_to :strategy
  attr_accessor :logger, :act, :current_situation
  serialize :options

  def self.trade_all_ichimokus
    Indicator.all.each do |indicator|
      strategy = Strategy.find_by(name: indicator.name) || Strategy.create(name: indicator.name, options: {indicator_id: indicator.id})

      trade = Trade.find_by(strategy_id: strategy.id) ||
        Trade.create(
          begin: indicator.ichimokus.order('time asc').first.time,
          end: indicator.ichimokus.order('time asc').last.time,
          initial_usd: 1000,
          usd: 1000,
          estimate_usd: 1000,
          btc: 0,
          strategy: strategy,
          options: {description: strategy.name, model_name: 'Hour'}
        )

      # AutoTrade.perform_async trade.id
      trade.auto_trade
    end
  end

  def auto_trade
    trade_results.delete_all

    time_model = model
    time_interval = MOD_INT[time_model.to_s]
    time = self.begin
    self.usd = self.initial_usd
    self.btc = 0

    self.end = time_model.order('time asc').last.time

    while time <= self.end
      self.current_situation = time_model.find_by(time: time)

      make_decision
      store_result

      time += time_interval
    end

    point_1 = trade_results.order('time asc').first.time
    point_2 = trade_results.where('time <= ?', Time.new(2013,10,12)).order('time asc').last.time
    point_3 = trade_results.where('time <= ?', Time.new(2013,11,29)).order('time asc').last.time
    point_4 = trade_results.order('time asc').last.time

    self.options[:low_volume] = profit_rate_by_range(point_1, point_2)
    self.options[:up] = profit_rate_by_range(point_2, point_3)
    self.options[:modern] = profit_rate_by_range(point_3, point_4)
    self.profit_rate = profit_rate_by_range(point_2, point_4)

    self.save!
  end

  def profit_rate_by_range from, to
    tr = trade_results.where('time >= ? AND time <= ?', from, to).order('time asc')
    pr = tr.present? ? (tr.last.estimate_usd / tr.first.estimate_usd).round(2) : 1
  end

  def make_decision
    ichi = Ichimoku.where(time: current_situation.time, indicator_id: strategy.options[:indicator_id]).first
    return nil unless ichi
    if usd > 0
      threshold = [ichi.senkou_span_a, ichi.senkou_span_b].max

      if current_situation.close >= threshold
        self.act = 'buy'
        buy_for(usd)
      end
    end

    if btc > 0
      threshold = [ichi.senkou_span_a, ichi.senkou_span_b].min

      if current_situation.close <= threshold
        self.act = 'sell'
        sell(btc)
      end
    end
  end

  def manual_trade
    buy_for(usd) if act == 'buy'
    sell(btc) if act == 'sell'
    store_result

    self.end += MOD_INT[options[:model_name]]
  end

  def to_s
    options[:description]
  end

  def last_tr
    trade_results.order('time asc').last
  end

  def model
    options[:model_name].constantize
  end

  def buy_for amount
    self.usd -= (amount).round(20)
    self.btc += ((amount / current_situation.close) * (1 - COMISSION)).round(20)
    self.estimate_usd = (self.usd + (self.btc * current_situation.close) * (1 - COMISSION)).round(20)
    self.estimate_btc = (self.btc + (self.usd / current_situation.close) * (1 - COMISSION)).round(20)
    self.profit_rate = (estimate_usd / initial_usd).round(2)
    save!
  end

  def sell amount
    self.btc -= (amount).round(20)
    self.usd += ((amount * current_situation.close) * (1 - COMISSION)).round(20)
    self.estimate_usd = (self.usd + (self.btc * current_situation.close) * (1 - COMISSION)).round(20)
    self.estimate_btc = (self.btc + (self.usd / current_situation.close) * (1 - COMISSION)).round(20)
    self.profit_rate = (estimate_usd / initial_usd).round(2)
    save!
  end

  def store_result
    return unless self.act == 'buy' || self.act == 'sell'
    TradeResult.create(time: current_situation.time, price: current_situation.close, usd: usd, estimate_usd: estimate_usd, estimate_btc: estimate_btc, btc: btc, trade: self, action: act)
    self.act = nil
  end
end
