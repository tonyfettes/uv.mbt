///|
pub(all) enum AsyncIterResult[E] {
  IterEnd(E?)
  IterContinue
}

///|
type AsyncIter[T, E] ((T) -> AsyncIterResult[E]) -> AsyncIterResult[E]
