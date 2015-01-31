function! undoing#graph#ascii#render(buf, state, type, char, text, coldata)
  " prints an ASCII graph of the DAG

  " takes the following arguments (one call per node in the graph):

  "   - Somewhere to keep the needed state in (init to asciistate())
  "   - Column of the current node in the set of ongoing edges.
  "   - Type indicator of node data == ASCIIDATA.
  "   - Payload: (char, lines):
  "     - Character to use as node's symbol.
  "     - List of lines to display as the node's text.
  "   - Edges; a list of (col, next_col) indicating the edges between
  "     the current node and its parents.
  "   - Number of columns (ongoing edges) in the current revision.
  "   - The difference between the number of columns (ongoing edges)
  "     in the next revision and the number of columns (ongoing edges)
  "     in the current revision. That is: -1 means one column removed;
  let [idx, edges, ncols, coldiff] = call('s:asciiedges', a:coldata)

  " [seen, node, parents] = [list, elem, list]

  echo '.'
  echo ['state', a:state, 'char', a:char, 'text', a:text]
  echo ['seen', undoing#node#print(a:coldata[0])]
  echo ['node', a:coldata[1].to_s()]
  echo ['parents', undoing#node#print(a:coldata[2])]
  echo ['idx', idx, 'edges', edges, 'ncols', ncols, 'coldiff', coldiff]
  if coldiff < -2 || coldiff > 2
    throw 'Something something'
  endif
  if coldiff == -1
    " Transform
    "
    "     | | |        | | |
    "     o | |  into  o---+
    "     |X /         |/ /
    "     | |          | |
    call s:fix_long_right_edges(edges)
  endif

  " add_padding_line says whether to rewrite
  "
  "     | | | |        | | | |
  "     | o---+  into  | o---+
  "     |  / /         |   | |  # <--- padding line
  "     o | |          |  / /
  "                    o | |
  let add_padding_line = (len(a:text) > 2) && (coldiff == -1)
        \ && ! empty(filter(copy(edges), 'v:val[0] + 1 < v:val[1]'))

  " fix_nodeline_tail says whether to rewrite
  "
  "     | | o | |        | | o | |
  "     | | |/ /         | | |/ /
  "     | o | |    into  | o / /   # <--- fixed nodeline tail
  "     | |/ /           | |/ /
  "     o | |            o | |
  let fix_nodeline_tail = len(a:text) <= 2 && ! add_padding_line

  " nodeline is the line containing the node character (typically o)
  let nodeline = repeat(['|', ' '], idx)
  call extend(nodeline, [a:char, ' '])

  call extend(nodeline,
        \ s:get_nodeline_edges_tail(
        \   idx, a:state[1], ncols, coldiff, a:state[0], fix_nodeline_tail))

  " shift_interline is the line containing the non-vertical
  " edges between this entry and the next
  let shift_interline = repeat(['|', ' '], idx)
  if coldiff == -1
    let n_spaces = 1
    let edge_ch = '/'
  elseif coldiff == 0
    let n_spaces = 2
    let edge_ch = '|'
  else
    let n_spaces = 3
    let edge_ch = '\'
  endif
  call extend(shift_interline, repeat([' '], n_spaces))
  call extend(shift_interline, repeat([edge_ch, ' '], ncols - idx - 1))

  " draw edges from the current node to its parents.
  call s:draw_edges(edges, nodeline, shift_interline)

  " lines is the list of all graph lines to print.
  let lines = [nodeline]
  if add_padding_line
    " TODO: append or extend here?
    call add(lines, s:get_padding_line(idx, ))
  endif
  call add(lines, shift_interline)

  " make sure that there are as many graph lines as there are
  " log strings
  while len(a:text) < len(lines)
    call add(a:text, '')
  endwhile
  if len(lines) < len(a:text)
    let extra_interline = repeat(['|', ' '], ncols + coldiff)
    while len(lines) < len(a:text)
      call add(lines, extra_interline)
    endwhile
  endif

  " print lines.
  let indentation_level = max([ncols, ncols + coldiff])
  for [line, logstr] in
        \ map(range(len(lines)), '[lines[v:val], a:text[v:val]]')
    let ln = printf('%-*s %s', 2 * indentation_level, join(line, ''), logstr)
    call extend(a:buf, [matchstr(ln, '^.*\S\ze\s*$')])
  endfor

  " ... and start over.
  let a:state[0] = coldiff
  let a:state[1] = idx
endfunction

function! s:asciiedges(seen, rev, parents)
  " Adds edge info to undotree DAG walk suitable for
  " undoing#graph#ascii#render()

  if index(a:seen, a:rev) == -1
    call add(a:seen, a:rev)
  endif

  let nodeidx = index(a:seen, a:rev)

  let knownparents = []
  let newparents = []

  for parent in a:parents
    if index(a:seen, parent) > -1
      call add(knownparents, parent)
    else
      call add(newparents, parent)
    endif
  endfor

  let ncols = len(a:seen)

  call remove(a:seen, nodeidx)
  call extend(a:seen, newparents, nodeidx)

  let edges = map(copy(knownparents), '[nodeidx, index(a:seen, v:val)]')

  if len(newparents) > 0
    call add(edges, [nodeidx, nodeidx])
  endif

  if len(newparents) > 1
    call add(edges, [nodeidx, nodeidx + 1])
  endif

  let nmorecols = len(a:seen) - ncols

  return [nodeidx, edges, ncols, nmorecols]
endfunction

function! s:get_nodeline_edges_tail(
      \ node_index, p_node_index, n_columns, n_columns_diff, p_diff, fix_tail
      \)
  if a:fix_tail && (a:n_columns_diff == a:p_diff) && (a:n_columns_diff != 0)
    " Still going in the same non-vertical direction.
    if a:n_columns_diff == -1
      let start = max([a:node_index + 1, a:p_node_index])
      let tail = repeat(['|', ' '], start - a:node_index - 1)
      call extend(tail, repeat(['/', ' '], a:n_columns - start))
      return tail
    else
      return repeat(['\', ' '], a:n_columns - a:node_index - 1)
    endif
  else
    return repeat(['|', ' '], a:n_columns - a:node_index - 1)
  endif
endfunction

function! s:draw_edges(edges, nodeline, interline)
  for [start, end] in a:edges
    if start == end + 1
      let a:interline[2 * end + 1] = '/'
    elseif start == end - 1
      let a:interline[2 * start + 1] = '\'
    elseif start == end
      let a:interline[2 * start] = '|'
    else
      let a:nodeline[2 * end] = '+'
      if start > end
        let [start, end] = [end, start]
      endif
      for i in range(2 * start + 1, 2 * end)
        if a:nodeline[i] != '+'
          let a:nodeline[i] = '-'
        endif
      endfor
    endif
  endfor
endfunction

function! s:fix_long_right_edges(edges)
  let i = 0
  let len = len(a:edges)
  while i < len
    let [start, end] = a:edges[i]
    if end > start
      let a:edges[i] = [start, end + 1]
    endif
    let i += 1
  endwhile
endfunction
