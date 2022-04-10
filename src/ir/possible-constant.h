/*
 * Copyright 2022 WebAssembly Community Group participants
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef wasm_ir_possible_constant_h
#define wasm_ir_possible_constant_h

#include <variant>

#include "ir/properties.h"
#include "wasm-builder.h"
#include "wasm.h"

namespace wasm {

// Represents data about what constant values are possible in a particular
// place. There may be no values, or one, or many, or if a non-constant value is
// possible, then all we can say is that the value is "unknown" - it can be
// anything. The values can either be literal values (Literal) or the names of
// immutable globals (Name).
//
// Currently this just looks for a single constant value, and even two constant
// values are treated as unknown. It may be worth optimizing more than that TODO
struct PossibleConstantValues {
private:
  // No possible value.
  struct None : public std::monostate {};

  // Many possible values, and so this represents unknown data: we cannot infer
  // anything there.
  struct Many : public std::monostate {};

  using Variant = std::variant<None, Literal, Name, Many>;
  Variant value;

public:
  PossibleConstantValues() : value(None()) {}

  // Notes the contents of an expression and update our internal knowledge based
  // on it and all previous values noted.
  void note(Expression* expr, Module& wasm) {
    // If this is a constant literal value, note that.
    if (Properties::isConstantExpression(expr)) {
      note(Properties::getLiteral(expr));
      return;
    }

    // If this is an immutable global that we get, note that.
    if (auto* get = expr->dynCast<GlobalGet>()) {
      auto* global = wasm.getGlobal(get->name);
      if (global->mutable_ == Immutable) {
        note(get->name);
        return;
      }
    }

    // Otherwise, this is not something we can reason about.
    noteUnknown();
  }

  // Note either a Literal or a Name.
  template<typename T> void note(T curr) {
    if (std::get_if<None>(&value)) {
      // This is the first value.
      value = curr;
      return;
    }

    if (std::get_if<Many>(&value)) {
      // This was already representing multiple values; nothing changes.
      return;
    }

    // This is a subsequent value. Check if it is different from all previous
    // ones.
    if (Variant(curr) != value) {
      noteUnknown();
    }
  }

  // Notes a value that is unknown - it can be anything. We have failed to
  // identify a constant value here.
  void noteUnknown() { value = Many(); }

  // Combine the information in a given PossibleConstantValues to this one. This
  // is the same as if we have called note*() on us with all the history of
  // calls to that other object.
  //
  // Returns whether we changed anything.
  bool combine(const PossibleConstantValues& other) {
    if (std::get_if<None>(&other.value)) {
      return false;
    }

    if (std::get_if<None>(&value)) {
      value = other.value;
      return true;
    }

    if (std::get_if<Many>(&value)) {
      return false;
    }

    if (other.value != value) {
      value = Many();
      return true;
    }

    return false;
  }

  // Check if all the values are identical and constant.
  bool isConstant() const {
    return !std::get_if<None>(&value) && !std::get_if<Many>(&value);
  }

  bool isConstantLiteral() const { return std::get_if<Literal>(&value); }

  bool isConstantGlobal() const { return std::get_if<Name>(&value); }

  // Returns the single constant value.
  Literal getConstantLiteral() const {
    assert(isConstant());
    return std::get<Literal>(value);
  }

  Name getConstantGlobal() const {
    assert(isConstant());
    return std::get<Name>(value);
  }

  // Assuming we have a single value, make an expression containing that value.
  Expression* makeExpression(Module& wasm) {
    Builder builder(wasm);
    if (isConstantLiteral()) {
      return builder.makeConstantExpression(getConstantLiteral());
    } else {
      auto name = getConstantGlobal();
      return builder.makeGlobalGet(name, wasm.getGlobal(name)->type);
    }
  }

  // Returns whether we have ever noted a value.
  bool hasNoted() const { return !std::get_if<None>(&value); }

  void dump(std::ostream& o) {
    o << '[';
    if (!hasNoted()) {
      o << "unwritten";
    } else if (!isConstant()) {
      o << "unknown";
    } else if (isConstantLiteral()) {
      o << getConstantLiteral();
    } else if (isConstantGlobal()) {
      o << '$' << getConstantGlobal();
    }
    o << ']';
  }
};

// Similar to the above, but it also allows *non*-constant values in that it
// will track their type. That is, this is a variant over
//  * No possible value.
//  * One possible constant value.
//  * One possible type but the value of that type is not constant.
//  * "Many" - either multiple constant values for one type, or multiple types.
struct PossibleValues {
private:
  // No possible value.
  struct None : public std::monostate {};

  // Many possible values, and so this represents unknown data: we cannot infer
  // anything there.
  struct Many : public std::monostate {};

  struct ImmutableGlobal {
    Name name;
    Type type;
    bool operator==(const ImmutableGlobal& other) const {
      return name == other.name && type == other.type;
    }
  };

  using Variant = std::variant<None, Literal, ImmutableGlobal, Type, Many>;
  Variant value;

public:
  PossibleValues() : value(None()) {}
  PossibleValues(Variant value) : value(value) {}

  // Notes the contents of an expression and update our internal knowledge based
  // on it and all previous values noted.
  void note(Expression* expr, Module& wasm) {
    // If this is a constant literal value, note that.
    if (Properties::isConstantExpression(expr)) {
      combine(Variant(Properties::getLiteral(expr)));
      return;
    }

    // If this is an immutable global that we get, note that.
    if (auto* get = expr->dynCast<GlobalGet>()) {
      auto* global = wasm.getGlobal(get->name);
      if (global->mutable_ == Immutable) {
        combine(Variant(ImmutableGlobal{get->name, global->type}));
        return;
      }
    }

    // Otherwise, note the type.
    // TODO: should we ignore unreachable here, or assume the caller has already
    //       run dce or otherwise handled that?
    combine(Variant(expr->type));
  }

  // Notes a value that is unknown - it can be anything. We have failed to
  // identify a constant value here.
  void noteUnknown() { value = Many(); }

  // Combine the information in a given PossibleValues to this one. This
  // is the same as if we have called note*() on us with all the history of
  // calls to that other object.
  //
  // Returns whether we changed anything.
  bool combine(const PossibleValues& other) {
    if (std::get_if<None>(&other.value)) {
      return false;
    }

    if (std::get_if<None>(&value)) {
      value = other.value;
      return true;
    }

    if (std::get_if<Many>(&value)) {
      return false;
    }

    if (std::get_if<Many>(&other.value)) {
      value = Many();
      return true;
    }

    // Neither is None, and neither is Many.

    if (other.value == value) {
      return false;
    }

    // The values differ, but if they share the same type then we can set to
    // that.
    if (other.getType() == getType()) {
      if (std::get_if<Type>(&value)) {
        // We were already marked as an arbitrary value of this type.
        return false;
      }        
      value = Type(getType());
      return true;
    }

    // Worst case.
    value = Many();
    return true;
  }

  // Check if all the values are identical and constant.
  bool isConstant() const {
    return !std::get_if<None>(&value) && !std::get_if<Many>(&value);
  }

  bool isConstantLiteral() const { return std::get_if<Literal>(&value); }

  bool isConstantGlobal() const { return std::get_if<ImmutableGlobal>(&value); }

  // Returns the single constant value.
  Literal getConstantLiteral() const {
    assert(isConstant());
    return std::get<Literal>(value);
  }

  Name getConstantGlobal() const {
    assert(isConstant());
    return std::get<ImmutableGlobal>(value).name;
  }

  Type getType() const {
    if (auto* literal = std::get_if<Literal>(&value)) {
      return literal->type;
    } else if (auto* global = std::get_if<ImmutableGlobal>(&value)) {
      return global->type;
    } else if (auto* type = std::get_if<Type>(&value)) {
      return *type;
    } else {
      WASM_UNREACHABLE("bad value");
    }
  }

  // Assuming we have a single value, make an expression containing that value.
  Expression* makeExpression(Module& wasm) {
    Builder builder(wasm);
    if (isConstantLiteral()) {
      return builder.makeConstantExpression(getConstantLiteral());
    } else {
      auto name = getConstantGlobal();
      return builder.makeGlobalGet(name, wasm.getGlobal(name)->type);
    }
  }

  // Returns whether we have ever noted a value.
  bool hasNoted() const { return !std::get_if<None>(&value); }

  void dump(std::ostream& o) {
    o << '[';
    if (!hasNoted()) {
      o << "unwritten";
    } else if (!isConstant()) {
      o << "unknown";
    } else if (isConstantLiteral()) {
      o << getConstantLiteral();
    } else if (isConstantGlobal()) {
      o << '$' << getConstantGlobal();
    }
    o << ']';
  }
};

} // namespace wasm

#endif // wasm_ir_possible_constant_h
