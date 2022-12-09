;; NOTE: Assertions have been generated by update_lit_checks.py and should not be edited.
;; RUN: foreach %s %t wasm-opt -all --efo --nominal -S -o - | filecheck %s

(module
  ;; CHECK:      (type $A (struct (field i32) (field i32)))
  (type $A (struct (field i32) (field i32)))
  ;; CHECK:      (type $B (struct (field i32) (field i32)))
  (type $B (struct (field i32) (field i32)))

  ;; CHECK:      (func $A (type $none_=>_none)
  ;; CHECK-NEXT:  (local $ref (ref $A))
  ;; CHECK-NEXT:  (local.set $ref
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (i32.const 10)
  ;; CHECK-NEXT:    (i32.const 10)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $A 0
  ;; CHECK-NEXT:    (local.get $ref)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $A 0
  ;; CHECK-NEXT:    (local.get $ref)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block ;; (replaces something unreachable we can't emit)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (i32.const 11)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block ;; (replaces something unreachable we can't emit)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (unreachable)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $A
    (local $ref (ref $A))
    ;; $A is always written the same value in both fields, so they are
    ;; equivalent, and we optimize to always read from field #0.
    (local.set $ref
      (struct.new $A
        (i32.const 10)
        (i32.const 10)
      )
    )
    (drop
      (struct.get $A 0
        (local.get $ref)
      )
    )
    (drop
      (struct.get $A 1   ;; This will be optimized to 0.
        (local.get $ref)
      )
    )
    ;; Unreachable things are ignored, and do not interfere with optimization.
    (drop
      (struct.new $A
        (unreachable)
        (i32.const 11)
      )
    )
    (drop
      (struct.get $A 1
        (unreachable)
      )
    )
  )

  ;; CHECK:      (func $B (type $none_=>_none)
  ;; CHECK-NEXT:  (local $ref (ref $B))
  ;; CHECK-NEXT:  (local.set $ref
  ;; CHECK-NEXT:   (struct.new $B
  ;; CHECK-NEXT:    (i32.const 10)
  ;; CHECK-NEXT:    (i32.const 11)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $B 0
  ;; CHECK-NEXT:    (local.get $ref)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $B 1
  ;; CHECK-NEXT:    (local.get $ref)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $B
    (local $ref (ref $B))
    (local.set $ref
      (struct.new $B
        (i32.const 10)
        (i32.const 11) ;; This value is different, so in this function we do not
                       ;; optimize at all, and the get indexes remain 0, 1.
      )
    )
    (drop
      (struct.get $B 0
        (local.get $ref)
      )
    )
    (drop
      (struct.get $B 1
        (local.get $ref)
      )
    )
  )
)

(module
  ;; CHECK:      (type $A (struct (field i32) (field i32)))
  (type $A (struct (field i32) (field i32)))

  ;; CHECK:      (func $A (type $i32_=>_none) (param $x i32)
  ;; CHECK-NEXT:  (local $ref (ref null $A))
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:   (local.set $ref
  ;; CHECK-NEXT:    (struct.new $A
  ;; CHECK-NEXT:     (i32.const 10)
  ;; CHECK-NEXT:     (i32.const 10)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (local.set $ref
  ;; CHECK-NEXT:    (struct.new $A
  ;; CHECK-NEXT:     (i32.const 20)
  ;; CHECK-NEXT:     (i32.const 20)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $A 0
  ;; CHECK-NEXT:    (local.get $ref)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $A (param $x i32)
    (local $ref (ref null $A))
    ;; Two struct.news, each with different values - but the equivalances are
    ;; the same in both, so we can optimize the get index below to 0.
    (if
      (local.get $x)
      (local.set $ref
        (struct.new $A
          (i32.const 10)
          (i32.const 10)
        )
      )
      (local.set $ref
        (struct.new $A
          (i32.const 20)
          (i32.const 20)
        )
      )
    )
    (drop
      (struct.get $A 1
        (local.get $ref)
      )
    )
  )
)

(module
  ;; CHECK:      (type $A (struct (field i32) (field i32)))
  (type $A (struct (field i32) (field i32)))

  ;; CHECK:      (func $A (type $i32_=>_none) (param $x i32)
  ;; CHECK-NEXT:  (local $ref (ref null $A))
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:   (local.set $ref
  ;; CHECK-NEXT:    (struct.new $A
  ;; CHECK-NEXT:     (i32.const 10)
  ;; CHECK-NEXT:     (i32.const 10)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (local.set $ref
  ;; CHECK-NEXT:    (struct.new $A
  ;; CHECK-NEXT:     (i32.const 20)
  ;; CHECK-NEXT:     (i32.const 22)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.get $A 1
  ;; CHECK-NEXT:    (local.get $ref)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $A (param $x i32)
    (local $ref (ref null $A))
    (if
      (local.get $x)
      (local.set $ref
        (struct.new $A
          (i32.const 10)
          (i32.const 10)
        )
      )
      (local.set $ref
        (struct.new $A
          (i32.const 20)
          (i32.const 22) ;; This changed, so we do not optimize. One struct.new
                         ;; without the proper equivalences stops us.
        )
      )
    )
    (drop
      (struct.get $A 1
        (local.get $ref)
      )
    )
  )
)

;; Test separate functions and a struct.new in a global. Here we can optimize.
(module
  ;; CHECK:      (type $A (struct (field i32) (field i32)))
  (type $A (struct (field i32) (field i32)))

  ;; CHECK:      (global $A (ref $A) (struct.new $A
  ;; CHECK-NEXT:  (i32.const 10)
  ;; CHECK-NEXT:  (i32.const 10)
  ;; CHECK-NEXT: ))
  (global $A (ref $A) (struct.new $A
    (i32.const 10)
    (i32.const 10)
  ))

  ;; CHECK:      (func $new-0 (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $new-0
    (drop
      (struct.new $A
        (i32.const 20)
        (i32.const 20)
      )
    )
  )

  ;; CHECK:      (func $new-1 (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $new-1
    (drop
      (struct.new $A
        (i32.const 20)
        (i32.const 20)
      )
    )
  )

  ;; CHECK:      (func $get (type $ref|$A|_=>_i32) (param $ref (ref $A)) (result i32)
  ;; CHECK-NEXT:  (struct.get $A 0
  ;; CHECK-NEXT:   (local.get $ref)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $get (param $ref (ref $A)) (result i32)
    (struct.get $A 1
      (local.get $ref)
    )
  )
)

;; Non-equivalence in the global prevents optimization.
(module
  ;; CHECK:      (type $A (struct (field i32) (field i32)))
  (type $A (struct (field i32) (field i32)))

  ;; CHECK:      (global $A (ref $A) (struct.new $A
  ;; CHECK-NEXT:  (i32.const 10)
  ;; CHECK-NEXT:  (i32.const 11)
  ;; CHECK-NEXT: ))
  (global $A (ref $A) (struct.new $A
    (i32.const 10)
    (i32.const 11)
  ))

  ;; CHECK:      (func $new-0 (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $new-0
    (drop
      (struct.new $A
        (i32.const 20)
        (i32.const 20)
      )
    )
  )

  ;; CHECK:      (func $new-1 (type $none_=>_none)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (struct.new $A
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:    (i32.const 20)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $new-1
    (drop
      (struct.new $A
        (i32.const 20)
        (i32.const 20)
      )
    )
  )

  ;; CHECK:      (func $get (type $ref|$A|_=>_i32) (param $ref (ref $A)) (result i32)
  ;; CHECK-NEXT:  (struct.get $A 1
  ;; CHECK-NEXT:   (local.get $ref)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $get (param $ref (ref $A)) (result i32)
    (struct.get $A 1
      (local.get $ref)
    )
  )
)
