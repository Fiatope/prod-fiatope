var NeighborlyPayment = Backbone.View.extend({
  el: '.payment',
  initialize: function() {
    _.bindAll(this, 'showContent');
    this.$('.methods input').click((function(_this) {
      return function(e) {
        _this.showContent(e);
        return _this.togglePaymentFee(e);
      };
    })(this));
    return this.$('.methods input:first').click();
  },
  showContent: function(e) {
    var $payment;
    this.$('.payment-method-option').removeClass('selected');
    $(e.currentTarget).parents('.payment-method-option').addClass('selected');
    this.$('.container .loading').addClass('show');
    this.$('.payment-method').addClass('loading-section');
    $payment = $("#" + ($(e.currentTarget).val()) + "-payment.payment-method");
    if ($payment.data('path')) {
      return $.get($payment.data('path')).success((function(_this) {
        return function(data) {
          _this.$('.payment-method').html('');
          $payment.html(data);
          Initjs.initializePartial();
          $payment.show();
          _this.$('.payment-method').removeClass('loading-section');
          _this.updatePaymentFeeInformationOnEngine();
          return _this.$('.container .loading').removeClass('show');
        };
      })(this));
    }
  },
  togglePaymentFee: function(e) {
    var $input, $target, value;
    $input = $('.total-value input');
    $target = this.$('.methods input:checked');
    if ($('[is-paying-fees]').length || $('#pay_payment_fees').is(':checked')) {
      value = $($target).data('value-with-fees');
      $('[data-pay-payment-fee]').val('1');
    } else {
      value = $($target).data('value-without-fees');
      $('[data-pay-payment-fee]').val('0');
    }
    if (value) {
      return $input.val("" + ($input.data('total-text')) + value);
    }
  },
  updatePaymentFeeInformationOnEngine: function() {
    if ($('#pay_payment_fees').length === 0) {
      return;
    }
    if ($('#pay_payment_fees').is(':checked')) {
      return $('[data-pay-payment-fee]').val('1');
    } else {
      return $('[data-pay-payment-fee]').val('0');
    }
  }
});


Neighborly.Payment = NeighborlyPayment;
$(document).ready(function() {
  if ($('.payment').length) {
    new NeighborlyPayment();
  }
});
