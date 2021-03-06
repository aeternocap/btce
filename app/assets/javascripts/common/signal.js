function get_signals(){
  var indicator_id = $('#indicator_id').find(":selected").val()
  var path = '/indicators/' + indicator_id + '/signals'

  $.get(path).done(function(data){
    $('#signals').html('')
    $.each(data, function(k, v){
      $('<span/>', {
        class: 'signal',
        text: k,
        'data-content': v,
        style: 'margin-right: 15px; color: blue; cursor: pointer;'
      }).appendTo('#signals')
    })
    subscribeDescriptionShow()
  })
}

function subscribeDescriptionShow(){
  $('.signal').on('click', function(){
    $('#description').html($(this).data('content')).show()
  })
}
