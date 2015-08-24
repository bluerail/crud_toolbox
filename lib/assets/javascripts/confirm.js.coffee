# Ref. to the currently active confirm class
current = null

# Base class
class Confirm
  constructor: (target) ->
    @target = $(target)
    go = =>
      current = this
      @open.call this

    if current? then current.close go else go()

  confirm: ->
    ''

  open: -> throw new Exception 'open() not defined'
  close: (cb) -> throw new Exception 'close() not defined'


###
Bootstrap popover

Basic usage:
  <a
    href="#a"
    class="btn btn-default"
    data-confirm="true"
  >Hello</a>

This will clone the button, `true' is a special value to use teh default text of
`Are you sure?'


Advanced usage to control the text & button:
  <a
    href="#b"
    class="btn btn-info"
    data-confirm="Don't click this you silly person"
    data-confirm-btnhtml="<i class='fa fa-fighter-jet'></i> Kokosnoot"
    data-confirm-btnclass="btn btn-success"
  >Let's go</a>
###
class Popover extends Confirm
  # Open
  open: ->
    btn = @_make_btn()

    content = if @target.attr('data-confirm') isnt 'true'
      @target.attr('data-confirm')
    else
      _('Weet je het zeker?')

    @target.popover
      html: true
      content: "#{content}<br>#{btn[0].outerHTML}"
      placement: 'auto top'
      trigger: 'manual'

    @_close_events btn
    @_dropdowns btn
    @target.popover 'show'

    # Damn, this is ugly, almost as ugly as the inability to easily add a class to
    # a popover or using DOM elements as content :-/
    # TODO: We may want to either extend the bootstrap popover class, or throw it
    # out and write something new (ie. better).
    (=>
      $('.popover').addClass 'popover-confirm'
      $('.popover-confirm .btn').remove()
      $('.popover-confirm .popover-content').append btn

      # This should be in in @_close_events(), but events don't seem to work right
      # so we can't...
      close = => @close.call this
      $('.popover-confirm').on 'mouseleave.popover', -> close.delay 2000
      $('.popover-confirm').on 'mouseenter.popover', -> close.cancel()
    ).delay 10


  # Close
  close: (cb=null) ->
    return if @_closing
    return unless current? and current is this

    @_closing = true

    @target.off 'mouseenter.popover mouseleave.popover'
    $(document).off 'click.confirm'
    @target.popover 'destroy'

    # hidden.bs.popover is never fired? Use setTimeout tricks
    klass = this
    f = setInterval ->
      return unless $('.popover-confirm').length is 0

      clearInterval f
      # TODO: Who doesn't .every() / .cancel() work?
      #this.cancel()
      current = null
      cb() if cb?
    , 25


  # Bind events
  _close_events: (btn) ->
    close = => @close.call this

    btn.on 'click', -> close()

    $(document).one 'keydown', (e) -> close() if e.keyCode is 27 # Esc
    $(document).on 'click.confirm', (e) ->
      close() if current? and $(e.target).closest('.popover-confirm').length is 0

    @target.on 'mouseleave.popover', -> close.delay 2000
    @target.on 'mouseenter.popover', -> close.cancel()


  # Keep dropdowns open
  _dropdowns: ->
    dropdown = @target.closest('.dropdown-menu').parent()
    return unless dropdown.length > 0

    dropdown.on 'hide.bs.dropdown', -> false
    dropdown.find('.dropdown-menu').css 'overflow-y', 'visible'

    # hidden.bs.popover is never fired? Use setTimeout tricks
    @target.on 'hide.bs.popover', ->
      (->
        dropdown.off 'hide.bs.dropdown'
        dropdown.find('.dropdown-toggle').dropdown 'toggle'
        dropdown.find('.dropdown-menu').css 'overflow-y', 'auto'
      ).delay 100


  # Make the button
  _make_btn: ->
    if @target.hasClass 'btn'
      btn = @target
        .clone true
        .removeAttr 'data-confirm'
        .removeClass 'pull-left pull-right'
    else
      btn = $("<a class='btn btn-default'>#{@target.html()}</a>")

      # TODO: data-confirm-href
      if @target.is('a')
        href = @target.attr 'href'
      else
        href = @target.find('a:first').attr 'href'

      btn.attr 'href', href

      # TODO: Copy all attributes? Or somthing ...
      btn.attr 'data-method', @target.attr('data-method') if  @target.attr 'data-method'

    btn.html @target.attr('data-confirm-btnhtml') if @target.attr('data-confirm-btnhtml')

    if @target.attr('data-confirm-btnclass')
      btn.attr 'class', @target.attr('data-confirm-btnclass')

    return btn


class Dialog extends Confirm
  open: ->
    dialog = $('''
      <div class="modal confirm-modal fade" role="dialog">
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-header">
              <button type="button" class="close" data-dismiss="modal">×</button>
              <h4 class="modal-title"></h4>
            </div>
            <div class="modal-body"></div>
            <div class="modal-footer"></div>
          </div>
        </div>
      </div>
    ''')

    dialog.find('.modal-header h4').html @target.attr('data-confirm-title') || window.top.location.origin

    if @target.attr('data-confirm') is 'true'
      dialog.find(".modal-body").html _('Weet je het zeker?')
    else
      dialog.find(".modal-body").html @target.attr('data-confirm')

    $(document.body).append dialog
    dialog.modal 'show'

  close: (cb) ->
    $('.confirm-modal').modal 'hide'

    (->
      $('.confirm-modal').remove()
      current = null
      cb() if cb
    ).after 200




# Which class do we use
#confirm_class = Dialog
confirm_class = Popover


# Bind event
jQuery.rails.allowAction = (elem) ->
  return true unless elem.attr 'data-confirm'
  return unless jQuery.rails.fire elem, 'confirm'

  c = new confirm_class elem
  return false
