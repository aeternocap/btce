require 'rest_client'

class Btce < ActiveRecord::Base
  def self.follow
    url = 'https://btc-e.com/api/3/trades/btc_usd'
    request_interval = 2.0
    limit = 300
    
    loop do
      begin
        trades = JSON.parse(RestClient.get "#{url}?limit=#{limit}")['btc_usd']  
      rescue Exception
        SULO1.error "#{Time.now}: bad request"
        sleep 0.5
        next
      end

      last_time_transaction = Transaction.order('time asc').last.time.to_i
      last_time_trade = trades.first["timestamp"]
      trades.delete_if do |trade| 
        trade["timestamp"] == last_time_trade || trade['timestamp'] <= last_time_transaction
      end

      trades.map! do |trade| 
        Transaction.new(time: Time.at(trade["timestamp"]), price: trade["price"], amount: trade["amount"])
      end

      save_batch trades

      limit = [[trades.count * 3, 100].max, 2000].min

      if limit < 500
        request_interval = [request_interval * 2.0, 30.0].min
      else 
        request_interval = [request_interval / 2.0, 0.01].max
      end

      SULO1.info "#{Time.now}: #{trades.count}"
      sleep request_interval
    end
  end
end