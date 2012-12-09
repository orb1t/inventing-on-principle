inventingOnPrinciple.Views.ApplicationView = Backbone.View.extend
  spacer: inventingOnPrinciple.getTemplate('spacer')()
  initialize: ->

    # Input
    @$code = $('#code')

    # Options
    @$comment = $('#comment')
    @$loc = $('#loc')
    @$range = $('#range')
    @$raw = $('#raw')

    # Output
    @$tokens = $('#tokens')
    @$syntax = $('#syntax')
    @$url = $('#url')
    @$vars = $('#vars')

    # Tabs
    @$syntaxTab = $('#tab_syntax')
    @$tokensTab = $('#tab_tokens')
    @$urlTab = $('#tab_url')
    @$codeTab = $('#tab_code')
    @$stateTab = $('#tab_state')

    @model.ast
      .on('change:text', @renderUrl, this)
      .on('change:tokens', @renderTokens, this)
      .on('change:ast', @renderSyntax, this)
      .on('change:decs', @renderDeclarations, this)
      .on('change:generatedCode', @renderGeneratedCode, this)
      .on('tracedFunctions', @renderFunctionTraces, this)
      .on('reparse', @parse, this)

    @model.on('error', @renderError, this)

  events:
    'change input[type=checkbox]': 'parse'
    'click .tab_link': 'switchTab'
    'click #run': 'runCode'

  clearConsole: ->
    $('#console').html ''

  runCode: ->
    @clearConsole()
    try
      eval(inventingOnPrinciple.model.text())
    catch e
      console.log 'run time error', e

  switchTab: (e) ->
    @$('li').removeClass 'active'
    $(e.currentTarget).parents('li').addClass 'active'
    @render()

  trackCursor: (editor) ->
    @model.trackCursor editor

  parse: (editor, changeInfo) ->
    editor ?= inventingOnPrinciple.codeEditor
    text = if editor? then editor.getValue() else @$code.val()
    @model.parse text, editor

  renderUrl: ->
    @$url.val location.protocol + '//' + location.host + location.pathname + '?code=' + encodeURIComponent(@model.text())  if @$urlTab.hasClass('active')

  renderTokens: ->
    @$tokens.html @model.tokens()  if @$tokensTab.hasClass('active')

  renderSyntax: ->
    @$syntax.html @model.ast()  if @$syntaxTab.hasClass('active')

  renderGeneratedCode: ->
    inventingOnPrinciple.outputcode.setValue @model.generatedCode()  if @$codeTab.hasClass('active')

  renderDeclarations: ->
    @$vars.empty()
    lines = []
    linenumber = undefined
    @model.ast.get('vars').each (varDec, i) ->
      linenumber = varDec.get('loc').start.line - 1
      view = new inventingOnPrinciple.Views.VariableView(model: varDec)
      lines[linenumber] = view

    @model.ast.get('funs').each (funDec, i) ->
      linenumber = funDec.get('loc').start.line - 1
      view = new inventingOnPrinciple.Views.FunctionView(model: funDec)
      lines[linenumber] = view

    _.each lines, (line) =>
      if line
        @$vars.append line.render().$el
        line.initTangle()  if line.initTangle
      else
        @$vars.append @spacer


  renderFunctionTraces: (histogram, funcs) ->

    max = inventingOnPrinciple.Options.max
    normalized = {}
    _.each histogram, (count, funcname) ->
      normalized[funcname] = count / max

    $lines = @$('#vars').children()

    # Clear previous function traces
    $lines.css('background-color', 'transparent')

    _.each funcs.reverse(), (func) ->
      start = func.loc.start.line - 1
      end = func.loc.end.line - 1
      weight = normalized[func.name]
      count = histogram[func.name]

      color = 'rgba(255, 0, 0, ' + util.mapValue(weight, 0.05, 0.9) + ')'
      $lineinfo = inventingOnPrinciple.getTemplate('lineinfo')(msg: count)
      $linesInRange = $lines.slice(start, end)
      $linesInRange.css 'background-color': color
      $linesInRange.find('.lineinfo').remove().end().append $lineinfo

    this

  clearError: ->
    if @errorLineNumber >= 0
      inventingOnPrinciple.codeEditor.setLineClass(@errorLineNumber, null, null)
      @$('#codeContainer .errorContainer').html ''

  renderError: (e) ->

    # Either the lineNumber is contained in the error object
    # Or guess that the error was due to the last change and use cursor's position
    ln = if e.lineNumber then e.lineNumber - 1 else inventingOnPrinciple.codeEditor.getCursor().line
    @clearError()

    inventingOnPrinciple.codeEditor.setLineClass ln, 'errorLine', 'errorLineBackground'
    @errorLineNumber = ln

    @$('#codeContainer .errorContainer')
      .html(inventingOnPrinciple.getTemplate('lineinfo')(msg: e.message))
      .css('top', (ln + 0.5) + 'em')
    this

  scrollVars: (scrollInfo) ->
    @$('#decsContainer').scrollTop scrollInfo.y

  render: ->
    @renderUrl()
    @renderTokens()
    @renderSyntax()
    @renderGeneratedCode()
    @renderDeclarations()