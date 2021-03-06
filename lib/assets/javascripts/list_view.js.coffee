#= require sugar
#= require jquery
#= require_directory .

req = null
pdata = null


show_search = (input, apply=true, delayed=true) ->
  if input.val() is ''
    input.removeClass('has-value')
    input.css 'display', '' unless input.attr 'data-sticky'
  else
    input.addClass('has-value').css 'display', 'block'

  if apply
    apply_search.cancel()
    apply_search.delay (if delayed then 200 else 0), $(input).closest '.list-view'

show_search_multi = (input) ->
  apply_search.cancel()
  apply_search $(input).closest('.list-view')

filter = (tbl) ->
  tbl
    .find('.filter')
    .toArray()
    .map (f) -> [$(f).closest('th').attr('data-column'), $(f).val().trim()]
    .filter (f) -> f[1] isnt ''
    .map (f) -> "#{f[0]}^#{f[1]}"

update_search_multi_label = (container) ->
  status = $(container).siblings('.filter-multi-status').find('.status-text')

  input_items = $(container).find('input')
  checked_items = $(container).find('input:checked')

  new_label = ''
  if input_items.length == checked_items.length || checked_items.length == 0
    new_label = 'Alles'
  else if checked_items.length > 1
    new_label = "#{checked_items.length} filters"
  else
    # one item checked
    new_label = checked_items.val()

  $(status).text(new_label)


filter_multi = (tbl) ->
  element =  tbl.find('.filter-multi')

  update_search_multi_label(element)

  $(element)
    .toArray()
    .map (f) ->
      col = $(f).closest('th').attr('data-column')
      values = $(f)
        .find('input:checked')
        .map -> this.value
        .toArray()
        .join('|')

      return null if values == ''

      "#{col}^#{values}"
    .compact()

apply_search = (tbl) ->
  filter_str = filter tbl
    .concat filter_multi tbl
    .join ','
    .trim()

  return if filter_str is '' and not chronicle.getQuery()['filter']?

  chronicle.setQueryParam 'filter', filter_str
  chronicle.setQueryParam 'tbl_id', tbl.attr('id')
  reload tbl


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


per = (e) ->
  e.preventDefault()
  tbl = $(this).closest('table')

  chronicle.setQueryParam 'per', $(this).attr('data-per')
  chronicle.setQueryParam 'tbl_id', tbl.attr('id')

  reload tbl


get_data = (tbl) ->
  query = chronicle.getQuery()
  return {
    filter: query.filter or ''
    order: query.order or ''
    per: query.per or ''
    tbl_id: query.tbl_id or ''
  }


# Reload table; if the query string changed
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

# We make a really weird URL. When people land back on this page, we
# want the selected multi-select filters to actually be selected.
# So here's a really weird function to do that.
initialize_multi_checkboxes = ->
  filters = /\?filter=([\w\d%\-_,]+)/.exec(window.location.search)

  return unless filters

  filters[filters.length - 1].split(',').each (filter) ->
    pairs = filter.split "%5E" # split on ^ for [['name', 'val|ue|s']]
    next unless pairs.length == 2 # value is empty

    name = pairs[0]
    values = pairs[1].split "%7C" # split on |

    $(".filter-multi input[name=#{name}]").each ->
      if this.value in values
        this.checked = true

# Fix column width to the current width, preventing auto resizing
fix_column_width = (tbl, width=null) ->
  tbl.find('thead th').toArray().each (th) ->
    $(th).css 'width', "#{$(th).outerWidth()}px"

$(document).ready ->
  $(document).on 'keydown ', '.list-view .filter', (e) -> show_search $(this)
  $(document).on 'blur change', '.list-view .filter', (e) -> show_search $(this), true, false
  $(document).on 'change', '.filter-multi input', (e) -> show_search_multi $(this)

  pdata = get_data $('.list-view')
  $$('.list-view .filter').each (f) -> show_search $(f), false
  $(document).on 'click', '.list-view th .order', order
  $(document).on 'click', '.list-view th .column', (e) ->
    b = $(this).next()
    b.click() if b.is('.order')

  $(document).on 'click', '.list-view .per', per

  $('.list-view').on 'click', 'tbody tr', (e) ->
    target = $(e.target)
    return if target.prop('tagName') is 'A' or target.hasClass('btn') or target.hasClass('fa')
    link = $(this).find('td:eq(1) > a:eq(0)').attr('href')
    window.location = link if link?

  initialize_multi_checkboxes()
  $('.filter-multi').each -> update_search_multi_label(this)

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
