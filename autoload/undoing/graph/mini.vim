function! undoing#graph#mini#render(...) "{{{
  let node = call('undoing#tree#new', a:000).root
  let lines = {
        \ 'current': 0,
        \ 'content': []
        \}
  function lines.to_s(...) "{{{
    let verbose = a:0 ? a:1 : 0
    if verbose == 0
      return join(map(copy(self.content), 'v:val.to_s(0)'), "\<nl>")
    elseif verbose == 1
      return 'current: ' . self.current . "\<NL>"
            \. join(map(copy(self.content), 'v:val.to_s(1)'), "\<nl>")
    else
      return 'current: ' . self.current . "\<NL>"
            \. join(map(copy(self.content), 'v:val.to_s(2)'), "\<nl>")
    endif
  endfunction "}}}

  let line = s:line(lines)
  call line.add_current(s:item('o', node))
  let lines.current += 1
  while line.active
    echo 'render: while: '
    call insert(lines.content, line)
    echo lines.to_s(1)
    let line = line.next_line()
  endwhile
  echo lines.to_s(0)
  return lines
endfunction "}}}

function! s:line(lines) "{{{
  let l = {}
  let l.current = 1
  let l.prev = []
  let l.lines = a:lines
  let l.n = 1
  let l.active = 0
  function l.init() "{{{
    let self.index = 0
    let self.items = []
    let self.active = 0
    let self.text = ''
    return self
  endfunction "}}}
  function l.next_line() "{{{
    let c = copy(self)
    let c.prev = self
    let c.n += 1
    let self.next = c
    call c.init()
    call c.add_items()
    return c
  endfunction "}}}
  function l.get_next_item(index) "{{{
    return self.item(a:index).next_item()
  endfunction "}}}
  function l.add_items() "{{{
    while self.index < len(self.prev.items)
      let [current, item] = self.prev.get_next_item(self.index)
      if current
        call self.add_current(item)
        let inc_current = 1
      else
        call self.add(item)
      endif
      let self.index += 1
    endwhile
    let self.lines.current += exists('inc_current')
  endfunction "}}}
  function l.add(item) "{{{
    let a:item.line = self
    let self.active += a:item.n == -1 ? 0 : 1
    call add(self.items, a:item)
  endfunction "}}}
  function l.add_current(item) "{{{
    if a:item.children_cnt > 1
      let child = a:item.next_child()
      let a:item.index -= 1
      call self.add(a:item)
      call self.add(child)
      call self.add_padding()
    else
      call self.add(a:item)
    endif
    let self.text = printf(' [%2s]', self.lines.current)
  endfunction "}}}
  function l.item(index) "{{{
    return self.items[a:index]
  endfunction "}}}
  function l.to_s(...) "{{{
    let verbose = a:0 ? a:1 : 0
    if verbose == 0
      return ' ' . join(map(copy(self.items), 'v:val.to_s(0)'), '') . self.text
    elseif verbose == 1
      return join(map(copy(self.items), 'v:val.to_s(1)'), ' ')
    else
      return printf('{n=%s, c=%s, a=%s, x: [%s]', self.n, self.lines.current, self.active, join(map(copy(self.items), 'v:val.to_s(2)'), ', '))
    endif
    return '{'
          \. 'n: ' . self.n . ', '
          \. 'c: ' . self.lines.current . ', '
          \. 'a: ' . self.active . ', '
            \. 'x: ' . get(get(self, 'next', {}), 'n', -1) . ', '
          \. ' [' . join(map(copy(self.items), 'v:val.to_s()'), ', ') . ']'
          \. '}'
  endfunction "}}}
  function l.add_padding() "{{{
    let line = self
    while !empty(line.prev)
      let line = line.prev
      let left = line.items[self.index]
      if self.index + 1 == len(line.items)
        let type = left.type =~ '[-]' ? '-' : ' '
        call add(line.items, left.new_empty(type))
      else
        let right = line.items[self.index + 1]
        let pair = left.type . right.type
        if pair =~# 'o[-+]' || pair =~# '+[-o]' || pair =~# '-[-+o]'
          let type = '-'
        else
          let type = ' '
        endif
        call insert(line.items, left.new_empty(type), self.index + 1)
      endif
    endwhile
    let self.index += 1
  endfunction "}}}
  call l.init()
  return l
endfunction "}}}

function! s:item(...) "{{{
  let d = {}
  function d.init(...) "{{{
    let self.type = a:0 ? a:1 : ' '
    let self.node = a:0 > 1 ? a:2 : {}
    let self.children_cnt = len(get(self.node, 'children', []))
    let self.n = get(self.node, 'n', -1)
    let text = ''
    let self.index = a:0 > 2 ? a:3 : len(get(self.node, 'children', [])) - 1
    return self
  endfunction "}}}
  function d.new_empty(...) "{{{
    let e = copy(self)
    let type = a:0 ? a:1 : ' '
    return e.init(type, {}, -1)
  endfunction "}}}
  function d.to_s(...) "{{{
    let verbose = a:0 ? a:1 : 0
    if verbose == 0
      return self.type
    elseif verbose == 1
      return printf('[%s %2s]', self.type, self.n)
    endif
    return '{'
          \ . 't: ' . self.type . ', '
          \ . 'l: ' . self.line.n . ', '
          \ . 'i: ' . self.index . ', '
          \ . 'node: {'  . ( empty(self.node) ? '' : self.node.to_s(1) ) . '}'
          \ . '}'
  endfunction "}}}
  function d.is_current() "{{{
    return  self.n == self.line.lines.current
  endfunction "}}}
  function d.is_parent() "{{{
    return self.n < self.line.lines.current && self.children_cnt > 0
  endfunction "}}}
  function d.clone(...) "{{{
    let c = copy(self)
    let c.type = a:0 ? a:1 : self.type
    return c
  endfunction "}}}
  function d.next_child(...) "{{{
    let type = a:0 ? a:1 : '+'
    let child = copy(self).init(type, self.node.children[self.index])
    if !a:0 && child.is_current()
      let child.type = 'o'
    endif
    return child
  endfunction "}}}
  function d.next_item() "{{{
    if self.n == -1
      return [0, self.new_empty()]
    elseif self.is_current()
      return [1, self.clone('o')]
    elseif self.is_parent()
      let child = self.next_child('o')
      if child.is_current()
        if self.index == 0
          return [1, child]
        else
          return [1, self.clone('+')]
        endif
      else
        return [0, self.clone('|')]
      endif
    elseif self.type == 'o' && self.index == -1
      return [0, self.new_empty()]
    else
      return [0, self.clone('|')]
    endif
  endfunction "}}}
  return call(d.init, a:000, d)
endfunction "}}}
