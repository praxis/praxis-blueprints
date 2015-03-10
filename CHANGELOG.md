# praxis-blueprints changelog

## next

* Added `include_nil` and `include_unset` options to `View` for refining the rendering of nil or unset values respectively. These can be set when defining the view with `Blueprint.view`, and default to false. For example: `view :default, include_unset: nil { ... }`.
  * `include_nil`: include attributes with `nil` values on the object (as checked with `@object.key?`).
  * `include_unset`: implies the above, as well as include attributes that are not set on the object.
* Added `Blueprint#key?` that delegates to `@object.key?`. 

* Fixed `Blueprint.describe` to output the proper `:id`. That is: the 'id` from the Class name, rather than the internal Struct attribute.
* Fixed `Blueprint.dump(nil)` raising a `NoMethodError`


## 1.2.0

* `Blueprint` readers now always `load` the value for an attribute before returning it.

## 1.1.0

* Added CollectionView, a special type of view that renders an array of objects with another view.


## 1.0.1

* Relaxed ActiveSupport version dependency (from 4 to >=3)


## 1.0

Initial release!