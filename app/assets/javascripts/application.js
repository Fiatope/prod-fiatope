//= require jquery.js 
// require jquery.turbolinks
//= require jquery_ujs
//= require jquery.remotipart
//= require turbolinks
//= require jquery.pjax
//= require foundation
//= require bootstrap-sprockets
//= require dropzone
//= require best_in_place
//= require ./lib/underscore.js
//= require ./lib/backbone.js
//= require neighborly/neighborly.js
//= require init.js
//= require_tree .
//= require_tree ./lib
//= require nprogress
//= require nprogress-turbolinks
//= require nprogress-pjax
//= require nprogress-ajax
//= require neighborly-mangopay-creditcard
//= require neighborly-admin
//= require jquery.ui.datepicker
//= require cocoon




var loaded = function(){

	document.addEventListener("turbolinks:load", function() {

   	// Fix image on home page if element exists
   	var homeImage = document.querySelector("body > div.discover.text-center > div.container > div > div.project-box.col-md-4.col-xs-12.environnement.left > a:nth-child(2) > div > div > img");
   	if (homeImage) {
   		homeImage.src = "https://kwendoo.s3.amazonaws.com/uploads/project/uploaded_image/2944/project_thumb_large_mangroove.jpg";
   		console.log("image okay home");
   	}


		$("#question1").click(function(){
			$("#answer1").toggleClass("bounce");
		});
	
		$("#question2").click(function(){
			$("#answer2").toggleClass("bounce");
		});
	
		$("#question3").click(function(){
			$("#answer3").toggleClass("bounce");
		});
	
		$("#question4").click(function(){
			$("#answer4").toggleClass("bounce");
		});
	
		$("#question5").click(function(){
			$("#answer5").toggleClass("bounce");
		});
	
		$("#question6").click(function(){
			$("#answer6").toggleClass("bounce");
		});
	
		$("#question7").click(function(){
			$("#answer7").toggleClass("bounce");
		});
	
		$("#question8").click(function(){
			$("#answer8").toggleClass("bounce");
		});
	
		$("#question9").click(function(){
			$("#answer9").toggleClass("bounce");
		});
	
		$("#question10").click(function(){
			$("#answer10").toggleClass("bounce");
		});
	
		$("#question11").click(function(){
			$("#answer11").toggleClass("bounce");
		});
	
		$("#question12").click(function(){
			$("#answer12").toggleClass("bounce");
		});
	
		$("#question13").click(function(){
			$("#answer13").toggleClass("bounce");
		});
	
		$("#question14").click(function(){
			$("#answer14").toggleClass("bounce");
		});
	
		$("#question15").click(function(){
			$("#answer15").toggleClass("bounce");
		});

		$("#question16").click(function(){
			$("#answer16").toggleClass("bounce");
		});

		$("#question17").click(function(){
			$("#answer17").toggleClass("bounce");
		});

		$("#question18").click(function(){
			$("#answer18").toggleClass("bounce");
		});

		$("#question19").click(function(){
			$("#answer19").toggleClass("bounce");
		});

		$("#question20").click(function(){
			$("#answer20").toggleClass("bounce");
		});

		$("#question21").click(function(){
			$("#answer21").toggleClass("bounce");
		});

		$("#project_partner").click(function(){
			$("#input_partner").toggleClass("bounce");
		});

		$("#gadzar-search").on("change keyup", function() {
			var val = $(this).val().toLowerCase();
			var $to_show = $("h3.name").filter(function() {
			  var caption = $(this).html().toLowerCase();
			  return caption.indexOf(val) != -1
			});
			var $to_hide = $("h3.name").not($to_show);
			$to_show.closest(".project-box").show();
			$to_hide.closest(".project-box").hide();
		});
		
		if ($(".cfa-equivalent").length) {
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
		}

		if ($('#project_about, #project_budget, #project_english, #partner_about, #project_terms').length) {
			$('#project_about, #project_budget, #project_english, #partner_about, #project_terms').markItUp(Neighborly.markdownSettings);
		}

		if ($('#profile_how_it_works, #profile_submit_your_project_text').length) {
			$('#profile_how_it_works, #profile_submit_your_project_text').markItUp(Neighborly.markdownSettings);
		}

		if ($('.contribution-info').length) {
			$('.contribution-info').on('click', function() {
				$('#' + $(this).data('reveal-id')).modal('show');
				return false;
			});
		}

		if ($('.custom-tooltip a').length) {
			$('.custom-tooltip a').on('click', function() {
				var tooltipContent = $(this).parents('.custom-tooltip').find('.tooltip-content');
				$('.tooltip-content').not('.hide').not(tooltipContent).toggleClass('hide');
				tooltipContent.toggleClass('hide');
				return false;
			});
		}

		if ($('.payment-method[data-path]').length) {
			$('.payment-method[data-path]').on('focusin', function() {
				$(this).find('form.payment').on('change', function() {
					if ($(this).find('input[type=radio]').length) {
						if ($(this).find('input[type=radio]:checked').val() == 'new') {
							$(this).find('.add-new-creditcard-form').removeClass('hide');
						} else {
							$(this).find('.add-new-creditcard-form').addClass('hide');
						}
					}
				});

				$(this).off('focusin');
			});
		}

		current_rewards_no_presale = $(".reward_in_check:input:radio").map(function(){
			return $(this);
		}).toArray();

		selected_reward = $(".selected:input:radio").map(function(){
				return $(this);
			}).toArray();

		if (selected_reward.length > 0){
			selected_reward[0].prop('checked', true);
		}else{
			if(current_rewards_no_presale.length > 0){
				current_rewards_no_presale[0].prop('checked', true);
			}
		}

		$(".error_amount").hide();
		if ($('form#form-contribution').length) {
			var current_rewards = [];
			$('form#form-contribution').on('change', function() {

				current_rewards = $(".reward_check:input:checkbox:checked").map(function(){
					return $(this).val();
				}).toArray();

				// selected_no_presale_mount = $(".reward_in_check:input:radio:checked").map(function(){
				// 	return $(this).val();
				// }).toArray();

				selected_no_presale_value = $(".reward_in_check:input:radio:checked").map(function(){
					return $(this);
				}).toArray();
			
				if(selected_no_presale_value.length > 0){
					// Insérer automatiquement le montant du reward dans le champ de contribution
					var rewardValue = parseInt(selected_no_presale_value[0].next('input[type=hidden]').val());
					if (!isNaN(rewardValue) && rewardValue > 0) {
						$('.value-wrapper').find('input[type=number]').val(rewardValue);
					}
				
					var inputs = $('.value-wrapper').find('input[type="number"]');
						inputs.keyup(function() {
						mount = $(this).val();
						if(parseInt(selected_no_presale_value[0].next('input[type=hidden]').val()) > mount){
							$('input[type=submit]').hide();
							if ($('.value-wrapper').find('input[type=number]').val() != '') {
								$(".error_amount").show();
							}
						}
	
						if(parseInt(selected_no_presale_value[0].next('input[type=hidden]').val()) <= mount){
							$('input[type=submit]').show()
							$(".error_amount").hide()
						}
					});
					
					if(parseInt(selected_no_presale_value[0].next('input[type=hidden]').val()) > $('.value-wrapper').find('input[type=number]').val()){
						$('input[type=submit]').hide();
						if ($('.value-wrapper').find('input[type=number]').val() != '') {
							$(".error_amount").show();
						}
					}

					if(parseInt(selected_no_presale_value[0].next('input[type=hidden]').val()) <= $('.value-wrapper').find('input[type=number]').val()){
						$('input[type=submit]').show()
						$(".error_amount").hide()
					}
				}
				var  sum = 0
				var num = 0
				$.each(current_rewards, function(i, reward) {
					var selectedReward = $('input[name="contribution_form[reward][minimum_value_'+reward+']"]')
					var val = selectedReward.val();
					num += parseInt(val);
					selectedReward.closest('.reward-option').find(".add-more-reward").css({ display: "block" });
					
					var count = selectedReward.closest('.reward-option').find('.add-more-reward > input[type=hidden]').val();
					sum += (parseInt(val) * parseInt(count))
					
					selectedReward.closest('.reward-option').find('a#down').click(function(event) {
						if(count > 1){
							count--;
							$(this).next().next().next('input[type=hidden]').val(count);
							$("a.cart > span").addClass("counter");
							var selected = $(this).next().next('a.cart').find('span.counter');
							selected.text(count)
						}
						event.preventDefault();
					});

					selectedReward.closest('.reward-option').find('a#up').click(function(event) {
						count++;
						$(this).next().next('input[type=hidden]').val(count);
						$("a.cart > span").addClass("counter");
						var selected = $(this).next('a.cart').find('span.counter');
						selected.text(count)
						
						event.preventDefault();
					});

					
					if ((selectedReward.closest('.reward-option').find('.article_check:input[type=checkbox]').length == 0) || selectedReward.closest('.reward-option').find('.reward_check:input[type=checkbox]:checked').length > maximum_articles) {
						$(this).find('input[type=submit]').prop("disabled",false);
						$(this).find('input[type=submit]').prop("disabled",false);
					} else {
						$(this).find('.article_check:input[type=checkbox]').prop("disabled",true);
						selectedReward.closest('.reward-option').find('.article_check:input[type=checkbox]').prop("disabled",false);						
						var maximum_articles = selectedReward.closest('.reward-option').find('input[type=hidden]').val();
						if (reward != selectedReward) {
							reward = selectedReward;
							$(this).find('.article_check:input[type=checkbox]').prop("checked",false);
							$(this).find('input[type=submit]').prop("disabled",true);
						}

						if ((selectedReward.closest('.reward-option').find('.article_check:input[type=checkbox]:checked').length == 0) || selectedReward.closest('.reward-option').find('input[type=checkbox]:checked').length > maximum_articles) {
							$(this).find('.article_check:input[type=submit]').prop("disabled",true);
						} else {
							$(this).find('input[type=submit]').prop("disabled",false);
						}
					}
				});

				$('a#up').click(function(event) {
					var newNum = 0
					var total = [];
					$.each(current_rewards, function(i, reward) {
						var selectedReward = $('input[name="contribution_form[reward][minimum_value_'+reward+']"]')
						var val = selectedReward.val();
						var count = selectedReward.closest('.reward-option').find('.add-more-reward > input[type=hidden]').val();
						newNum = (parseInt(val) * parseInt(count))
						total.push(newNum);
					})

					sum = total.reduce(function(a,b){  return a+b },0)
					if (!isNaN(sum)) {
					 	$('.value-wrapper').find('input[type=number]').val(sum);
					}
				})

				$('a#down').click(function(event) {
					var newNum = 0
					var total = [];
					$.each(current_rewards, function(i, reward) {
						var selectedReward = $('input[name="contribution_form[reward][minimum_value_'+reward+']"]')
						var val = selectedReward.val();
						var count = selectedReward.closest('.reward-option').find('.add-more-reward > input[type=hidden]').val();

						newNum = (parseInt(val) * parseInt(count))
						total.push(newNum);
					})

					sum = total.reduce(function(a,b){  return a+b },0)
					if (!isNaN(sum)) {
					 	$('.value-wrapper').find('input[type=number]').val(sum);
					}
				})

				if (!isNaN(sum)) {
					$(this).find('.total_with_reward:input[type=number]').val(sum);
				}

				var checkedes = $("input:checkbox:checked").map(function(){
					return $(this);
				}).toArray();

				if(checkedes){
					$(this).find('input[type=submit]').prop("disabled",false);
				}else{
					$(this).find('input[type=submit]').prop("disabled",true);
				}
			});
		}

		if ($('form#new_project').length) {
			$('form#new_project').on('change', function() {
				if ($(this).find('input[name="project[presale]"]').length) {
					if ($(this).find('input[name="project[presale]"]:checked').val() == '1') {
						$(this).find('input[name="project[goal]"]').val(0);
						$(this).find('input[name="project[goal]"]').prop("readonly",true);
						$(this).find('input[name="project[presale_goal]"]').prop("readonly",false);
					} else {
						$(this).find('input[name="project[goal]"]').prop("readonly",false);
						$(this).find('input[name="project[presale_goal]"]').val(0);
						$(this).find('input[name="project[presale_goal]"]').prop("readonly",true);
					}
				}
			});
		}

		if ($('.rewards').length) {
			var rewards = $('.rewards');

			$.ajax({
				url: rewards.data("rewards-path"),
				type: 'GET',
				success: function(data) {
					rewards.html(data);
				}
			});
		}

		var Lscreen = screen.width;
		var numberOfPartnersSlideVisible = 4;

		$('.customer-logos').slick({
			slidesToShow: numberOfPartnersSlideVisible,
			slidesToScroll: 1,
			autoplay: true,
			autoplaySpeed: 1500,
			arrows: false,
			dots: false,
			pauseOnHover: false,
			responsive: [
			  {
				breakpoint: 768,
				settings: {
				  slidesToShow: 3
				}
			  },
			  {
				breakpoint: 520,
				settings: {
				  slidesToShow: 2
				}
			  }
			]
		});

		if ($('.js-load-more').length) {
			var page = $('.contributions-page');

			var loader = $('.contributions-loading img');
			var loaderDiv = $('.contributions-loading');
			var filter = { page: 2 };
	  
			$('.js-load-more').click(function(){
				loader.show();

				$.ajax({
					url: page.data('path') + '?page=' + filter.page,
					type: 'GET',
					success: function(data) {
						var dataDiv = $(data).filter('div');

						if (dataDiv.length) {
							page.find('.list .custom-tooltip > a').unbind('click');

							page.find('.list').append(dataDiv);

							if (page.find('.list .custom-tooltip > a').length) {
								page.find('.list .custom-tooltip > a').on('click', function() {
									var tooltipContent = $(this).parents('.custom-tooltip').find('.tooltip-content');
									$('.tooltip-content').not('.hide').not(tooltipContent).toggleClass('hide');
									tooltipContent.toggleClass('hide');
									return false;
								});
							}
					
							filter.page += 1;
						}

						loader.hide();
					}
				});
		
				return false;
			});
		}

		var nameCookie = 'cookie-consent';
		var expireDay = 365;

		if (getCookie(nameCookie) === undefined) {
			setTimeout(function () {
				$("#cookieConsent").fadeIn(200);
				$("#cookieConsentModal").modal('show');
			}, 1500);
		}

		$("#closeCookieConsent").click(function() {
			$("#cookieConsent").fadeOut(200);
		});

		$(".cookieConsentOK").click(function() {
			var consentOK = 'yes';

			if ($('#cookie_session').is(":checked")) {
				consentOK += ',cs';
			}

			if ($('#cookie_google_analytics').is(":checked")) {
				consentOK += ',cga';
			}

			setCookie(nameCookie, consentOK, expireDay);

			$("#cookieConsent").fadeOut(200);
			$("#cookieConsentModal").modal('hide');
		});

		$(".cookieConsentKO").click(function() {
			setCookie(nameCookie, 'no', expireDay);

			$("#cookieConsent").fadeOut(200);
			$("#cookieConsentModal").modal('hide');
		});

		$(".openCookieConsentModal").click(function(){
			$("#cookieConsentModal").modal('show');
		
			return false;
		});

		$('#cookieConsentModal .modal-footer button').on('click', function(event) {
			var consentBtn = $(event.target); // The clicked button
		  
			$(this).closest('.modal').one('hidden.bs.modal', function() {
				// Fire if the button element 

				if (consentBtn.data('accepte') == 'yes') {
					var consentOK = 'yes';

					if ($('#cookie_session').is(":checked")) {
						consentOK += ',cs';
					}

					if ($('#cookie_google_analytics').is(":checked")) {
						consentOK += ',cga';
					}
		
					setCookie(nameCookie, consentOK, expireDay);
		
					$("#cookieConsent").fadeOut(200);
				}

				if (consentBtn.data('accepte') == 'no') {
					setCookie(nameCookie, 'no', expireDay);

					$("#cookieConsent").fadeOut(200);
				}
			});
		});

		if ($('.flash').length) {
			// setTimeout(function(){
			// 	$('.flash .alert-box.dismissible').slideUp('slow');
			// }, 15000);

			$('.flash .dismissible a.close').click(function(){
				$('.flash .alert-box.dismissible').slideUp('slow');
			
				return false;
			});
		}

		// initMap();
	});
}

var initMap = function() {
	var optionsAutocomplete = {
		types: ['(cities)'],
	};

	if (document.getElementsByClassName('search-cities-with-google').length) {
		var searchInput = document.getElementsByClassName('search-cities-with-google')[0];

		var autocomplete = new google.maps.places.Autocomplete(searchInput, optionsAutocomplete);

		var lat = 49.268661;
		var lng = 20.249441;

		var coordinates = new google.maps.LatLng(lat,lng);

		var mapCanvas = document.getElementsByClassName('map-canvas')[0];

		var map = new google.maps.Map(mapCanvas, {
			center: coordinates,
			zoom: 11
		});
		
		autocomplete.bindTo('bounds', map);
		
		var infowindow = new google.maps.InfoWindow();

		var marker = new google.maps.Marker({
			position: coordinates,
			map: map
		});

		google.maps.event.addListener(autocomplete, 'place_changed', function() {
			var place = autocomplete.getPlace();

			if (place.geometry.viewport) {
				map.fitBounds(place.geometry.viewport);
			} else {
				map.setCenter(place.geometry.location);
				map.setZoom(16); // Why 17? Because it looks good.
			}

			var image = new google.maps.MarkerImage(
				place.icon,
				new google.maps.Size(71, 71),
				new google.maps.Point(0, 0),
				new google.maps.Point(17, 34),
				new google.maps.Size(35, 35)
			);
			marker.setIcon(image);
			marker.setPosition(place.geometry.location);

			var address = '';

			if (place.address_components) {
				address = [(place.address_components[0] &&
				place.address_components[0].short_name || ''),
				(place.address_components[1] &&
				place.address_components[1].short_name || ''),
				(place.address_components[2] &&
				place.address_components[2].short_name || '')
				].join(' ');
			}

			infowindow.setContent('<div><strong>' + place.name + '</strong><br>' + address);
			infowindow.open(map, marker);

			google.maps.event.addListener(marker, 'click', function() {
				return place
			});
		});
	}
}

function getCookie(name) {
    var matches = document.cookie.match('(^|;) ?' + name + '=([^;]*)(;|$)');
    return matches ? matches[2] : undefined;
}

function setCookie(name, value, days) {
    var d = new Date;
    d.setTime(d.getTime() + 24*60*60*1000*days);
    document.cookie = name + "=" + value + ";path=/;expires=" + d.toGMTString();
}

function deleteCookie(name) { setCookie(name, '', -1); }

$(document).on("page:load ready", loaded);

$(document).ready(function() {


	$('.has-animation').each(function(index) {
	  $(this).delay($(this).data('delay')).queue(function(){
		$(this).addClass('animate-in');
	  });
	});
	$('.has-animation').each(function(index) {
	  $(this).delay($(this).data('delay')).queue(function(){
		$(this).addClass('animate-in');
	  });
	});
  });
  

