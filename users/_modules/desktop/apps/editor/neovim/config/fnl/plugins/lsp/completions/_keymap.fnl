{:preset :none
 :<Tab> [(fn [cmp]
           (if (cmp.snippet_active)
               (cmp.accept)
               (cmp.select_and_accept)))
         :snippet_forward
         :fallback]
 :<S-Tab> [:snippet_backward :fallback]
 :<A-j> [:select_next]
 :<A-k> [:select_prev]
 :<C-d> [:scroll_documentation_down]
 :<C-u> [:scroll_documentation_up]
 :<C-k> [:show_signature :hide_signature]}
