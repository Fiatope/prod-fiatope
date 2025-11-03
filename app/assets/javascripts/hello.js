
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
