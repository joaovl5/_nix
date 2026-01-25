(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (let-req [hi :mini.hipatterns]
                  (let [hi_words MiniExtra.gen_highlighter.words]
                    (hi.setup {:highlighters {:fixme (hi_words [:FIXME
                                                                :Fixme
                                                                :fixme]
                                                               :MiniHipatternsFixme)
                                              :hack (hi_words [:HACK
                                                               :Hack
                                                               :hack]
                                                              :MiniHipatternsHack)
                                              :todo (hi_words [:TODO
                                                               :Todo
                                                               :todo]
                                                              :MiniHipatternsTodo)
                                              :note (hi_words [:NOTE
                                                               :Note
                                                               :note]
                                                              :MiniHipatternsNote)}
                               :hex_color (hi.gen_highlighter.hex_color)})))))
