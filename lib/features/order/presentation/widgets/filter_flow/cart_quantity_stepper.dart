import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The quantity control that *is* the add-to-cart action.
///
/// There is no separate "Add" button anywhere in the product list: quantity
/// above zero means the line is in the quotation, zero means it isn't. That
/// removes a whole class of "I tapped add but nothing happened" confusion and
/// halves the taps for the common case of ordering several of one SKU.
///
/// The number is tappable. Steppers are for nudging; a rep entering 250 tonnes
/// should not be holding a `+`.
///
/// ## Nothing gates this control
///
/// Not stock, not the unit, not a price. Material selection is independent of
/// both: a rep may put any catalogue material on a quotation, and stock and
/// pricing are settled later in the flow.
///
/// Three gates have been removed from here in turn, each of which silently
/// killed the `+` button:
///
///  * `enabled: product.isAvailable` — reads an `availableQuantity` the
///    materials API never fills;
///  * `max: availableQuantity.floor()` — i.e. `0`, read as a ceiling;
///  * `stock.canOrder` — SAP's verdict, which answers about a sales area the
///    handset had often not supplied.
///
/// The only bound left is [maxQuantity], a slipped-thumb guard.
///
/// ## Instant on screen, debounced to the cart
///
/// The displayed number is **local state**, updated on the same frame as the
/// tap. It does not wait for the cart write to come back, so a held `+` ramps
/// at frame rate instead of at the speed of a database round trip.
///
/// The write is debounced by [_commitDelay]: a long press that runs from 3 to
/// 240 produces one cart update, not two hundred and thirty-seven. Each of
/// those would otherwise persist a row and rebuild the whole product grid,
/// which is what made the control feel heavy.
///
/// [didUpdateWidget] adopts the parent's value whenever no write is in flight,
/// so an external change — another card editing the same line, a cart reload —
/// still lands. While a write *is* pending the local value wins, because it is
/// the newer of the two.
///
/// Named [CartQuantityStepper] rather than `QuantityStepper` because the older
/// standalone `widgets/filter/quantity_stepper.dart` still exists; two widgets
/// with the same class name in one feature is a trap for the next person.
class CartQuantityStepper extends StatefulWidget {
  const CartQuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.maxQuantity = typoGuard,
  });

  /// The largest quantity the field will accept.
  ///
  /// A guard against a slipped thumb turning 25 into 250000 — **not a stock
  /// ceiling**, and not derived from anything the server said. Nothing on the
  /// wire supplies an on-hand figure to bound against; the band is a
  /// description, not a limit.
  static const int typoGuard = 999999;

  final int quantity;

  /// Called with the new quantity on every change, including zero — the caller
  /// treats zero as "remove this line".
  final ValueChanged<int> onChanged;

  final int maxQuantity;

  @override
  State<CartQuantityStepper> createState() => _CartQuantityStepperState();
}

/// How long the control waits after the last change before writing.
///
/// Long enough to swallow a burst of taps, short enough that letting go and
/// looking at the cart shows the new number already there.
const _commitDelay = Duration(milliseconds: 220);

class _CartQuantityStepperState extends State<CartQuantityStepper> {
  Timer? _repeat;
  Timer? _commitTimer;
  bool _editing = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// What the rep sees. Ahead of [CartQuantityStepper.quantity] while a write
  /// is still on its way to the cart.
  late int _local = widget.quantity;

  bool get _writePending => _commitTimer?.isActive ?? false;

  bool get _canDecrease => _local > 0;
  bool get _canIncrease => _local < widget.maxQuantity;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      // Tapping away commits rather than discards — the number on screen is
      // what the rep meant, whether or not they found the done key.
      if (!_focusNode.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant CartQuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity == oldWidget.quantity || widget.quantity == _local) {
      return;
    }
    // A burst is still being typed or tapped out — the local value is the
    // newer of the two, so the parent's echo of an older state must not fight
    // the rep's thumb.
    if (_writePending) return;
    // Nothing in flight, and the parent disagrees with us: it is authoritative.
    // This covers a rejected write and an edit made somewhere else, both of
    // which would otherwise leave a number on screen that nothing backs.
    _local = widget.quantity;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    // Never drop a change on the floor because the card scrolled out of view
    // or the screen was popped: flush synchronously on the way out.
    if (_writePending) {
      _commitTimer?.cancel();
      widget.onChanged(_local);
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Moves the number now and schedules the write for when the taps stop.
  /// [fromField] marks a change the text field itself produced.
  ///
  /// It exists so the controller is written back for a button press but not
  /// for a keystroke: echoing the rep's own typing into the controller would
  /// reset the caret to the end on every character.
  void _setLocal(int next, {bool immediate = false, bool fromField = false}) {
    if (next == _local) {
      // Already showing it, but a debounced write may still be queued behind
      // it — Done must not leave that hanging.
      if (immediate && _writePending) {
        _commitTimer?.cancel();
        widget.onChanged(next);
      }
      return;
    }
    setState(() => _local = next);

    // The `+` and `-` buttons stay live while the field is open, so the field
    // has to follow them. Without this the number under the caret kept saying
    // 800 while the value being committed climbed past it.
    if (_editing && !fromField) {
      _controller.text = '$next';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }

    _commitTimer?.cancel();
    if (immediate) {
      widget.onChanged(next);
      return;
    }
    _commitTimer = Timer(_commitDelay, () {
      if (!mounted) return;
      widget.onChanged(_local);
    });
  }

  void _beginEdit() {
    _controller.text = '$_local';
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    setState(() => _editing = true);
  }

  /// Each keystroke, clamped and scheduled like a button press.
  ///
  /// A cleared field is deliberately ignored rather than treated as zero: the
  /// rep is part-way through replacing the number, and blanking the line under
  /// them mid-edit would be its own bug. [_commit] applies the same rule when
  /// they leave the field.
  void _onTyped(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    _setLocal(_clamp(parsed), fromField: true);
  }

  int _clamp(int value) {
    if (value < 0) return 0;
    return value > widget.maxQuantity ? widget.maxQuantity : value;
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    setState(() => _editing = false);

    // An empty or unparseable field is not an instruction to remove the line.
    // It is a rep who cleared the box and tapped away, so nothing changes.
    if (parsed == null) return;

    // Typed and confirmed, so there is no burst to wait out — write it now.
    // Nothing may be left pending behind a dismissed keyboard.
    _setLocal(_clamp(parsed), immediate: true);
  }

  void _step(int delta) {
    final next = _local + delta;
    if (next < 0 || next > widget.maxQuantity) return;
    HapticFeedback.selectionClick();
    _setLocal(next);
  }

  /// Long press ramps up: slow at first so a held thumb doesn't overshoot by
  /// twenty, then faster once the intent is obvious.
  void _startRepeat(int delta) {
    _repeat?.cancel();
    var elapsed = 0;
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      elapsed += 90;
      final fast = elapsed > 900;
      if (!fast && elapsed % 180 != 0) return;
      if (delta > 0 ? !_canIncrease : !_canDecrease) {
        timer.cancel();
        return;
      }
      _step(delta);
    });
  }

  void _stopRepeat() {
    if (_repeat == null) return;
    _repeat?.cancel();
    _repeat = null;
    // Rebuild so the number's key stops being pinned to 'ramp' and a
    // subsequent single tap animates again.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final inCart = _local > 0;

    // Reduce-motion collapses every duration in this widget to zero rather than
    // guarding each one separately (feature-ui-standard §14). The two *timers*
    // below — the commit debounce and the press-and-hold repeat — are untouched
    // by it: they are behaviour, not motion, and zeroing them would commit a
    // quantity on every keystroke and make press-and-hold ungovernable.
    final motion = (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : null;

    return AnimatedContainer(
      duration: motion ?? AppDurations.medium,
      curve: AppCurves.standard,
      decoration: BoxDecoration(
        color: inCart
            ? scheme.primary.withValues(alpha: 0.10)
            : colors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inCart ? scheme.primary : colors.border,
          width: inCart ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: _canDecrease,
            onTap: () => _step(-1),
            onLongPressStart: () => _startRepeat(-1),
            onLongPressEnd: _stopRepeat,
          ),
          SizedBox(
            // Wider while editing so a six-digit quantity is not typed into a
            // slot built for two. 250000 has to fit without the caret pushing
            // the leading digits out of view.
            width: _editing ? context.rw(66) : context.rw(38),
            child: _editing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: false),
                    textInputAction: TextInputAction.done,
                    // Typing commits as it goes, on the same debounce as the
                    // buttons. Waiting for Done meant the cart and the
                    // quotation preview sat on the old number while a rep
                    // looked straight at the new one and reasonably concluded
                    // nothing had happened.
                    onChanged: _onTyped,
                    onSubmitted: (_) => _focusNode.unfocus(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                          '${widget.maxQuantity}'.length),
                    ],
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _beginEdit,
                    child: AnimatedSwitcher(
                      // `fast`, not `medium`. A digit is closest to the token
                      // doc's "badge swap", but this one is driven by repeated
                      // taps and press-and-hold — at 250ms the number visibly
                      // lags behind the finger.
                      duration: motion ?? AppDurations.fast,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Text(
                        '$_local',
                        // A held `+` changes this every frame; cross-fading
                        // each step would smear the number into illegibility,
                        // so the switcher is pinned during a repeat and only
                        // animates a deliberate single tap.
                        key: ValueKey(_repeat == null ? _local : 'ramp'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: inCart ? scheme.primary : colors.textSecondary,
                          fontSize: context.rsp(14),
                          fontWeight: FontWeight.w800,
                          // A dotted underline is the only affordance saying
                          // this number is a field. Without it a rep holds `+`
                          // to reach 250 rather than typing it, which is the
                          // behaviour the text entry exists to replace.
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                          decorationColor:
                              (inCart ? scheme.primary : colors.textSecondary)
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: _canIncrease,
            onTap: () => _step(1),
            onLongPressStart: () => _startRepeat(1),
            onLongPressEnd: _stopRepeat,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onLongPressStart: enabled ? (_) => onLongPressStart() : null,
      onLongPressEnd: enabled ? (_) => onLongPressEnd() : null,
      onLongPressCancel: enabled ? onLongPressEnd : null,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: AnimatedOpacity(
            // Micro feedback: an affordance dimming as it becomes unavailable.
            duration: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                ? Duration.zero
                : AppDurations.fast,
            opacity: enabled ? 1 : 0.3,
            child: Icon(icon, size: context.rr(17), color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
