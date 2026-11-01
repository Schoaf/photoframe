/// How long a slide stays: a photo [interval]; a shorter video loops for
/// [interval], a longer one plays once to its end.
Duration slideDuration(Duration interval, {Duration? videoLength}) =>
    videoLength != null && videoLength > interval ? videoLength : interval;
