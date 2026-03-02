// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lib.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CoreError {

 String get reason;
/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreErrorCopyWith<CoreError> get copyWith => _$CoreErrorCopyWithImpl<CoreError>(this as CoreError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'CoreError(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $CoreErrorCopyWith<$Res>  {
  factory $CoreErrorCopyWith(CoreError value, $Res Function(CoreError) _then) = _$CoreErrorCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$CoreErrorCopyWithImpl<$Res>
    implements $CoreErrorCopyWith<$Res> {
  _$CoreErrorCopyWithImpl(this._self, this._then);

  final CoreError _self;
  final $Res Function(CoreError) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reason = null,}) {
  return _then(_self.copyWith(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CoreError].
extension CoreErrorPatterns on CoreError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CoreError_Message value)?  message,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CoreError_Message() when message != null:
return message(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CoreError_Message value)  message,}){
final _that = this;
switch (_that) {
case CoreError_Message():
return message(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CoreError_Message value)?  message,}){
final _that = this;
switch (_that) {
case CoreError_Message() when message != null:
return message(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String reason)?  message,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CoreError_Message() when message != null:
return message(_that.reason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String reason)  message,}) {final _that = this;
switch (_that) {
case CoreError_Message():
return message(_that.reason);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String reason)?  message,}) {final _that = this;
switch (_that) {
case CoreError_Message() when message != null:
return message(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class CoreError_Message extends CoreError {
  const CoreError_Message({required this.reason}): super._();
  

@override final  String reason;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreError_MessageCopyWith<CoreError_Message> get copyWith => _$CoreError_MessageCopyWithImpl<CoreError_Message>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreError_Message&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'CoreError.message(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $CoreError_MessageCopyWith<$Res> implements $CoreErrorCopyWith<$Res> {
  factory $CoreError_MessageCopyWith(CoreError_Message value, $Res Function(CoreError_Message) _then) = _$CoreError_MessageCopyWithImpl;
@override @useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$CoreError_MessageCopyWithImpl<$Res>
    implements $CoreError_MessageCopyWith<$Res> {
  _$CoreError_MessageCopyWithImpl(this._self, this._then);

  final CoreError_Message _self;
  final $Res Function(CoreError_Message) _then;

/// Create a copy of CoreError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(CoreError_Message(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
