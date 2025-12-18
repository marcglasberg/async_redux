I have a question about the OptimisticUpdate mixin. Should it always be
non-reentrant? Could it be a problem that an action is dispatched a second time
when the first hasn't finished? Just analyze.

Ok. See how Throttle has a `Object? lockBuilder() => runtimeType;`, and how
Fresh as `Object? freshKeyParams() => null;` and
`Object computeFreshKey() => (runtimeType, freshKeyParams());`. Should a similar
thing be implemented with OptimisticUpdate expecting the user to use the
NonReentrant mixin, and if so, what should be the default?","
