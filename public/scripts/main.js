window.addEventListener('load', function() {
  $("p.leave_comment").on('click', function(){
    $("div.leave_comment").show()
  })
  $("#post_comment").on('click', function(){
    $("div.leave_comment").hide()
  })
})
