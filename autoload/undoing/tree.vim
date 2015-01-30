function! s:make_nodes(alts, nodes, nmap, parent) "{{{1
  let parent = a:parent
  for alt in a:alts
    let curhead = has_key(alt, 'curhead')
    let newhead = has_key(alt, 'newhead')
    let node = undoing#node#new(alt.seq, parent, alt.time, curhead, newhead)
    call extend(a:nmap, {node.n: node})
    call add(a:nodes, node)
    if has_key(alt, 'alt')
      call s:make_nodes(alt.alt, a:nodes, a:nmap, parent)
    endif
    let parent = node
  endfor
endfunction

function! s:by_node_num(...)
  return a:2.n - a:1.n
endfunction

function! undoing#tree#new(...)
  let tree = {}
  let tree.undotree = {}
  let tree.nodes = [undoing#node#root()]
  let tree.root = tree.nodes[0]
  let tree.nmap = {}

  if a:0
    let tree.undotree = a:1
  else
    let tree.undotree = undotree()
  endif

  call s:make_nodes(tree.undotree.entries, tree.nodes, tree.nmap, tree.root)
  unlet tree.undotree

  func tree.dag() dict
    " WARNING: deepcopy() not possible because nodes is cyclic
    " TODO: do we need to copy self.nodes here at all?
          " \ , '[v:val, !empty(v:val.parent) ? [v:val.parent] : []]')
    return map(sort(copy(self.nodes), 's:by_node_num')
          \ , '[v:val, [v:val.parent]]')
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
