/// Cross-platform file picking helper.
///
/// On the web we implement picking directly with a controlled <input> element
/// instead of `file_picker`, because file_picker's web backend detaches the
/// input element from the DOM immediately after calling `.click()`. Most
/// browsers then null out `input.files` by the time the `change` event fires,
/// which crashes with "Null check operator used on a null value".
/// Keeping the element attached until selection completes avoids that.
library file_pick;

export 'file_pick_native.dart' if (dart.library.html) 'file_pick_web.dart';
