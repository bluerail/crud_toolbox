# TODO: We could class-fy this

req = null
pdata = null


# Show the filter field +input+
show_filter = (input, apply=true, delayed=true) ->
  if input.val() is ''
    input.removeClass('has-value')
    input.css 'display', '' unless input.attr 'data-sticky'
  else
    input.addClass('has-value').css 'display', 'block'

  if apply
    apply_filter.cancel()
    apply_filter.delay (if delayed then 200 else 0), $(input).closest '.list-view'


# Apply all filters set for +tbl+
apply_filter = (tbl) ->
  filter = (tbl.find('.filter').toArray()
    .map (f) -> [$(f).closest('th').attr('data-column'), $(f).val().trim()]
    .filter (f) -> f[1] isnt ''
    .map (f) -> "#{f[0]}^#{f[1]}"
    .join ','
    .trim())

  return if filter is '' and not chronicle.getQuery()['filter']?

  chronicle.setQueryParam 'filter', filter
  chronicle.setQueryParam 'tbl_id', tbl.attr('id')
  reload tbl


# Set the order
# TODO: Also take previous sort into account
order = (e) ->
  icon = $(this).find '.fa'
  tbl = $(this).closest('table')

  if icon.hasClass('fa-sort') or icon.hasClass('fa-sort-desc')
    dir = 'asc'
  else
    dir = 'desc'

  $(this).closest('thead').find('.order .fa').attr 'class', 'fa fa-sort'
  icon.attr 'class', "fa fa-sort-#{dir}"

  chronicle.setQueryParam 'order', "#{$(this).closest('th').attr 'data-column'} #{dir}"
  chronicle.setQueryParam 'tbl_id', tbl.attr('id')
  reload tbl


# Set how many records to show
per = (e) ->
  e.preventDefault()
  tbl = $(this).closest('table')

  chronicle.setQueryParam 'per', $(this).attr('data-per')
  chronicle.setQueryParam 'tbl_id', tbl.attr('id')

  reload tbl


# Get teh current filter/order/etc. settings for +tbl+
get_data = (tbl) ->
  query = chronicle.getQuery()
  return {
    filter: query.filter or ''
    order: query.order or ''
    per: query.per or ''
    tbl_id: query.tbl_id or ''
  }


# Reload table from the server
reload = (tbl) ->
  req.abort() if req

  data = get_data tbl
  return if Object.equal data, pdata
  pdata = data

  fix_column_width tbl
  req = jQuery.ajax
    url: tbl.attr('data-url') or window.location.pathname
    data: data
    dataType: 'json'
    success: (data) ->
      req = null
      tbl.find('tbody').html data.tbody
      tbl.find('thead tr:first')[0].outerHTML = data.buttons
      tbl.find('tfoot').html data.buttons


# Fix column width to the current width. This prevents (annoying) auto-resizing
# when filtering.
#
# TODO: Maybe we want this to be an option? Or a button?
fix_column_width = (tbl, width=null) ->
  tbl.find('thead th').toArray().each (th) ->
    $(th).css 'width', "#{$(th).outerWidth()}px"


$(document).ready ->
  pdata = get_data $('.list-view')

  # Filter when input has changed
  $(document).on 'keydown ', '.list-view .filter', (e) -> show_filter $(this)
  $(document).on 'blur change', '.list-view .filter', (e) -> show_filter $(this), true, false

  # Show filter fields
  $$('.list-view .filter').each (f) -> show_filter $(f), false
  $(document).on 'click', '.list-view th .order', order
  $(document).on 'click', '.list-view th .column', (e) ->
    b = $(this).next()
    b.click() if b.is('.order')

  # Toggle display of all filters
  $('.list-view').on 'click', '.show-all-search', (e) ->
    e.preventDefault()

    filters = $(this).closest('table').find '.filter'

    if $(this).prop 'clicked'
      $(this).prop 'clicked', false
      filters.each ->
        return if $(this).val() isnt ''
        $(this)
          .removeAttr 'data-sticky'
          .css 'display', ''
    else
      $(this).prop 'clicked', true
      filters.each ->
        $(this)
          .attr 'data-sticky', true
          .css 'display', 'block'

  # Change pagination
  $(document).on 'click', '.list-view .per', per

  # Open the link when we click anywhere
  # TODO: We can CSS this, so we don't really need this
  $('.list-view').on 'click', 'tbody tr', (e) ->
    target = $(e.target)
    return if target.prop('tagName') is 'A' or target.hasClass('btn') or target.hasClass('fa')
    link = $(this).find('td:eq(1) > a:eq(0)').attr('href')
    window.location = link if link?

  # Checkboxes
  $('.list-view').on 'change', 'thead input[type=checkbox]', (e) ->
    if $(this).hasClass 'semi-active'
      $(this).closest('table').find('tbody input[type=checkbox]').prop 'checked', false
      $(this)
        .removeClass 'semi-active'
        .prop 'checked', false
    else if $(this).prop 'checked'
      $(this).closest('table').find('tbody input[type=checkbox]').prop 'checked', true
    else
      $(this).closest('table').find('tbody input[type=checkbox]').prop 'checked', false

  $('.list-view').on 'change', 'tbody input[type=checkbox]', (e) ->
    if $(this).prop 'checked'
      $(this).closest('table').find('thead input[type=checkbox]')
        .addClass 'semi-active'
        .prop 'checked', true
    else if $(this).closest('tbody').find('input[type=checkbox]:checked').length is 0
      $(this).closest('table').find('thead input[type=checkbox]')
        .removeClass 'semi-active'
        .prop 'checked', false
