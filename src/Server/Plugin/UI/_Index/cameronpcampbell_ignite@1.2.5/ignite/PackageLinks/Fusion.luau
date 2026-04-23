local PackagesIndex = script.Parent.Parent.Parent.Parent

local FusionPath = PackagesIndex["elttob_fusion@0.3.0"].fusion

local FusionTypes = require(FusionPath.Types)

type Fusion = FusionTypes.Fusion

export type Animatable = FusionTypes.Animatable
export type UsedAs<T> = FusionTypes.UsedAs<T>
export type Child = FusionTypes.Child
export type Computed<T> = FusionTypes.Computed<T>
export type Contextual<T> = FusionTypes.Contextual<T>
export type GraphObject = FusionTypes.GraphObject
export type For<KO, VO> = FusionTypes.For<KO, VO>
export type Observer = FusionTypes.Observer
export type PropertyTable = FusionTypes.PropertyTable
export type Scope<Constructors = Fusion> = FusionTypes.Scope<Constructors>
export type ScopedObject = FusionTypes.ScopedObject
export type SpecialKey = FusionTypes.SpecialKey
export type Spring<T> = FusionTypes.Spring<T>
export type StateObject<T> = FusionTypes.StateObject<T>
export type Task = FusionTypes.Task
export type Tween<T> = FusionTypes.Tween<T>
export type Use = FusionTypes.Use
export type Value<T, S = T> = FusionTypes.Value<T, S>
export type Version = FusionTypes.Version

return require(FusionPath)