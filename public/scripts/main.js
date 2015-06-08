window.addEventListener('load', function() {
  var open = false
  $("p.leave_comment").on('click', function(){
    if (open === false) {
      $("div.leave_comment").show()
      open = true;
    }
    else if (open === true) {
      $("div.leave_comment").hide()
      open = false;
    }
  })
  $("#post_comment").on('click', function(){
    $("div.leave_comment").hide()
  })




})
