ready = ->
  $("#user_birthday").datepicker(
    dateFormat: "dd/mm/yy"
    changeMonth: true
    changeYear: true
    yearRange: "-100y:c+nn"
    maxDate: "-1d"
  )
$(document).ready(ready)
$(document).on('page:load', ready)
