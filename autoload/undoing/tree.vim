function! s:make_nodes(alts, nodes, parent) "{{{1
  let parent = a:parent
  for alt in a:alts
    let curhead = has_key(alt, 'curhead')
    let newhead = has_key(alt, 'newhead')
    let node = undoing#node#new(alt.seq, parent, alt.time, curhead, newhead)
    call add(a:nodes, node)
    if has_key(alt, 'alt')
      call s:make_nodes(alt.alt, a:nodes, parent)
    endif
    let parent = node
  endfor
endfunction

function! s:by_node_num(...)
  return a:2.n - a:1.n
endfunction

function! undoing#tree#new(...)
  let tree = {}
  let tree.tree = {}
  let tree.nodes = [undoing#node#new(0, {}, 0, 0, 0)]
  let tree.root = tree.nodes[0]
  let tree.nmap = {}

  if a:0
    let tree.tree = a:1
  else
    let tree.tree = undotree()
  endif

  call s:make_nodes(tree.tree.entries, tree.nodes, tree.root)

  for node in tree.nodes
    call extend(tree.nmap, {node.n: node})
    let node.children = filter(copy(tree.nodes), 'v:val.parent is node')
  endfor

  func tree.dag() dict
    let dag = sort(deepcopy(self.nodes), 's:by_node_num')
    return map(dag, '[v:val, !empty(v:val.parent) ? [v:val.parent] : []]'),
  endfunc

  func tree.print() dict
    let l = []
    for n in self.nodes
      call extend(l, [n.to_s()])
    endfor
    return string(l)
  endfunction

  func tree.changenr() dict
    for node in self.nodes
      if node.curhead
        return node.parent.n
      endif
    endfor
    return changenr()
  endfunction

  return tree
endfunc
