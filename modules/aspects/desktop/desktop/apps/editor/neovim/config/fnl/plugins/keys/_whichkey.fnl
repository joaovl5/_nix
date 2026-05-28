{:preset :modern
 :plugins {:spelling {:enabled false}}
 :win {:title true
       :no_overlap false
       :padding [0 0]
       :border :none
       :width {:max 400}}
 :layout {:spacing 1 :width {:min 50}}
 :sort [:group :local :order :mod :alphanum :case]
 :delay 0
 :icons {:group "◦"}
 :triggers [{1 :<auto> :mode :nixsotc}
            {1 ";" :mode [:n]}
            {1 :t :mode [:n]}]}
