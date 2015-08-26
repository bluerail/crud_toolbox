# Several tools to aid with the history API; including no-ops for browsers that
# don't support it (chiefly, IE<=9, Android<=4.1)
#
# Note there is a "polyfill" as https://github.com/browserstate/history.js, this
# is a bit of a crappy library, and doesn't work very well at all (Oh how I have
# tried).
window.chronicle =
  ### No-ops ###
  go: (delta) -> window.history?.go? delta
  back: -> window.history?.back?()
  forward: -> window.history?.forward?()

  pushState: (data, title, url) ->
    return unless window.history?.pushState?

    # Turbolinks compat (makes the back button work)
    data = Object.extended().merge {
      turbolinks: true
      url: "#{window.location.protocol}//#{window.location.host}/#{url}"
    }, data, true
    window.history.pushState data, title, url
  replaceState: (data, title, url) -> window.history?.replaceState? data, title, url


  ### Additions ###


  # Better url{en,de}code
  urldecode: (url) -> decodeURIComponent url.replace(/\+/g, ' ')
  urlencode: (url) ->
    url = JSON.stringify url unless Object.isString url
    encodeURI(url).replace /%20/g, '+'


  # Get query parameters as Object
  getQuery: ->
    return Object.extended() if window.location.search is ''
    window.location.search.substr(1).split('&').map((v) => v.split('=').map(@urldecode)).toObject()


  # Set query parameters through an object
  #
  # This will overriding all existing query parameters
  setQuery: (query) ->
    str = '?' + ("#{@urlencode k}=#{@urlencode v}" for own k, v of query).join '&'

    if window.history?.pushState?
      @pushState null, null, window.location.pathname + str + window.location.hash
    else
      window.location.search = str


  # Set the query parameter /k/ to the value of /v/
  setQueryParam: (k, v) ->
    query = @getQuery()
    query[k] = v
    @setQuery query


Array.prototype.toObject = ->
  obj = Object.extended()
  this.each (a) -> obj[a[0]] = a[1]
  return obj
