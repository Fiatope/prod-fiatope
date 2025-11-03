$(document).ready(function() {
  $("#gadzar-search").on("change keyup", function() {
    var val = $(this).val().toLowerCase();
    var $to_show = $("h4.name").filter(function() {
      var caption = $(this).html().toLowerCase();
      return caption.indexOf(val) != -1
    });
    var $to_hide = $("h4.name").not($to_show);
    $to_show.closest(".project-box").show();
    $to_hide.closest(".project-box").hide();
  });

  $("body").on("click", ".delete-card", function() {
    var card_idd = $(this).data("card-id");
    $.ajax({
      url: "../../../../cards/"+card_idd+"/delete",
      success: function(a, b, res) {
        if (res.responseJSON.success) {
          $("[data-card-id='"+ res.responseJSON.card_id+"']").closest(".large-12.columns").remove();
        }
      }
    });
  });

});
