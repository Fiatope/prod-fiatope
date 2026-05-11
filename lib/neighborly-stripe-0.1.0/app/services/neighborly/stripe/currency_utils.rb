require 'bigdecimal'

module Neighborly
  module Stripe
    module CurrencyUtils
      ZERO_DECIMAL_CURRENCIES = %w[
        BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF UGX VND VUV XAF XOF XPF
      ].freeze

      # Stripe enforces minimums by settlement currency, but 0.50 equivalent is a safe floor.
      MINIMUM_MINOR_UNITS_BY_CURRENCY = {
        'EUR' => 50,
        'USD' => 50,
        'GBP' => 30,
        'JPY' => 50,
        'KRW' => 50,
        'XOF' => 50,
        'XAF' => 50
      }.freeze

      CURRENCY_ALIASES = {
        'FCFA' => 'XOF',
        'CFA' => 'XOF',
        'CFAF' => 'XOF'
      }.freeze

      module_function

      def normalize_currency(currency)
        code = currency.to_s.strip.upcase
        if %w[FCFA CFA CFAF].include?(code)
          configured = ENV.fetch('STRIPE_FCFA_CURRENCY', 'XOF').to_s.strip.upcase
          return %w[XOF XAF].include?(configured) ? configured : 'XOF'
        end

        code = CURRENCY_ALIASES.fetch(code, code)
        code.empty? ? 'EUR' : code
      end

      def zero_decimal_currency?(currency)
        ZERO_DECIMAL_CURRENCIES.include?(normalize_currency(currency))
      end

      def decimal_places(currency)
        zero_decimal_currency?(currency) ? 0 : 2
      end

      def minor_multiplier(currency)
        decimal_places(currency).zero? ? 1 : 100
      end

      def amount_to_minor_units(amount, currency)
        value = BigDecimal(amount.to_s)
        multiplier = BigDecimal(minor_multiplier(currency).to_s)
        (value * multiplier).round(0, BigDecimal::ROUND_HALF_UP).to_i
      end

      def amount_from_minor_units(minor_amount, currency)
        multiplier = BigDecimal(minor_multiplier(currency).to_s)
        return BigDecimal(minor_amount.to_s) if multiplier == 1

        BigDecimal(minor_amount.to_s) / multiplier
      end

      def minimum_minor_units(currency)
        code = normalize_currency(currency)
        MINIMUM_MINOR_UNITS_BY_CURRENCY.fetch(code, 50)
      end

      def amount_meets_minimum?(amount, currency)
        amount_to_minor_units(amount, currency) >= minimum_minor_units(currency)
      end
    end
  end
end
