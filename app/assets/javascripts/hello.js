
// Gestion du sélecteur de devise
$(document).ready(function() {
	var currentCurrency = 'EUR';
	var conversionRate = 656;
	
	$('.currency-btn').on('click', function() {
		var selectedCurrency = $(this).data('currency');
		
		// Mettre à jour les boutons
		$('.currency-btn').removeClass('active').css({
			'background': 'transparent',
			'color': 'white'
		});
		$(this).addClass('active').css({
			'background': 'white',
			'color': '#A3320C'
		});
		
		// Convertir la valeur existante
		var currentValue = parseFloat($('#contribution_form_value').val()) || 0;
		var newValue = currentValue;
		
		if (currentCurrency === 'EUR' && selectedCurrency === 'FCFA') {
			// EUR → FCFA
			newValue = Math.round(currentValue * conversionRate);
		} else if (currentCurrency === 'FCFA' && selectedCurrency === 'EUR') {
			// FCFA → EUR
			newValue = (currentValue / conversionRate).toFixed(2);
		}
		
		$('#contribution_form_value').val(newValue);
		$('#selected_currency').val(selectedCurrency);
		
		// Mettre à jour le préfixe et le max
		if (selectedCurrency === 'FCFA') {
			$('.currency-prefix').text('FCFA');
			$('#contribution_form_value').attr('max', 2500 * conversionRate); // 2500 EUR = ~1,640,000 FCFA
		} else {
			$('.currency-prefix').text($('.currency-prefix').data('original-symbol') || '€');
			$('#contribution_form_value').attr('max', 2500); // 2500 EUR
		}
		
		currentCurrency = selectedCurrency;
		updateCfaConversion();
	});
	
	// Sauvegarder le symbole original
	$('.currency-prefix').data('original-symbol', $('.currency-prefix').text());
});

$("#contribution_form_value").on("change", function(e) {
			e.preventDefault();
			var num = $(this).val();
			if (isNaN(num)) {
				$("#cfa-value").html(0.0);
			} else {
				var conversion_rate = $(".cfa-equivalent").data("conversion-rate");
				var cfa = parseFloat(num) * 656;
				$("#cfa-value").html(Math.round(cfa));
			}
			});
