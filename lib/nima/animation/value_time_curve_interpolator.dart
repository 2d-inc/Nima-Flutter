import "dart:math";

import "../readers/stream_reader.dart";
import "keyframe.dart";

// AE style curve interpolation
class ValueTimeCurveInterpolator extends KeyFrameInterpolator {
  double _inFactor;
  double _inValue;
  double _outFactor;
  double _outValue;

  double get inFactor => _inFactor;
  double get inValue => _inValue;
  double get outFactor => _outFactor;
  double get outValue => _outValue;
  ValueTimeCurveInterpolator();
  ValueTimeCurveInterpolator.fromValues(
      this._inFactor, this._inValue, this._outFactor, this._outValue);

  @override
  bool setNextFrame(KeyFrameWithInterpolation frame, KeyFrame nextFrame) {
    // This frame is a hold, return false to remove the interpolator.
    // We store it in the first place as when it gets called as the
    // nextFrame parameter (in a previous call) we still read out the
    // in factor and in value (see below where nextInValue and nextInFactor
    //  are defined).
    if (frame.interpolationType == InterpolationTypes.Hold) {
      return false;
    }

    // Just a sanity check really, both keyframes need to be numeric.
    KeyFrameNumeric ourFrame = frame as KeyFrameNumeric;
    KeyFrameNumeric next = nextFrame as KeyFrameNumeric;
    if (ourFrame == null || next == null) {
      return false;
    }

    // We are not gauranteed to have a next interpolator
    // (usually when the next keyframe is linear).
    ValueTimeCurveInterpolator nextInterpolator;

    double timeRange = next.time - ourFrame.time;
    double outTime = ourFrame.time + timeRange * _outFactor;

    double nextInValue = 0.0;
    double nextInFactor = 0.0;

    // Get the invalue and infactor from the next interpolator
    // (this is where hold keyframes get their interpolator values
    //  processed too).
    if (next.interpolator is ValueTimeCurveInterpolator) {
      nextInterpolator = next.interpolator as ValueTimeCurveInterpolator;
      nextInValue = nextInterpolator._inValue;
      nextInFactor = nextInterpolator._inFactor;
    } else {
      // Happens when next is linear.
      nextInValue = next.value;
    }

    double inTime = next.time - timeRange * nextInFactor;

    // Finally we can generate the curve.
    initializeCurve(ourFrame.time, ourFrame.value, outTime, _outValue, inTime,
        nextInValue, next.time, next.value);
    return true;
  }

  static ValueTimeCurveInterpolator read(
      StreamReader reader, InterpolationTypes type) {
    ValueTimeCurveInterpolator vtci = ValueTimeCurveInterpolator();
    switch (type) {
      case InterpolationTypes.Mirrored:
      case InterpolationTypes.Asymmetric:
      case InterpolationTypes.Disconnected:
        vtci._inFactor = reader.readFloat64("inFactor");
        vtci._inValue = reader.readFloat32("inValue");
        vtci._outFactor = reader.readFloat64("outFactor");
        vtci._outValue = reader.readFloat32("outValue");
        return vtci;

      case InterpolationTypes.Hold:
        vtci._inFactor = reader.readFloat64("inFactor");
        vtci._inValue = reader.readFloat32("inValue");
        vtci._outFactor = 0.0;
        vtci._outValue = 0.0;
        return vtci;
      default:
        break;
    }

    return null;
  }

  static const double EPSILON = double.minPositive;

  double _x0;
  double _y0;

  double _x1;
  double _y1;

  double _x2;
  double _y2;

  double _x3;
  double _y3;

  double _e;
  double _f;
  double _g;
  double _h;

  static const double DEBUG_VALUE = 7.325263977050781;

  void initializeCurve(double x0, double y0, double x1, double y1, double x2,
      double y2, double x3, double y3) {
    //ourFrame.time, ourFrame.value, outTime, _outValue, inTime, nextInValue, next.time, next.value
    _x0 = x0;
    _y0 = y0;

    _x1 = x1;
    _y1 = y1;

    _x2 = x2;
    _y2 = y2;

    _x3 = x3;
    _y3 = y3;

    _e = y3 - 3.0 * y2 + 3.0 * y1 - y0;
    _f = 3.0 * y2 - 6.0 * y1 + 3.0 * y0;
    _g = 3.0 * y1 - 3.0 * y0;
    _h = y0;
  }

  double cubicRoot(double v) {
    if (v < 0.0) {
      return -pow(-v, 1.0 / 3.0).toDouble();
    }
    return pow(v, 1.0 / 3.0).toDouble();
  }

  // http://stackoverflow.com/questions/27176423/function-to-solve-cubic-equation-analytically
  int solveCubic(double a, double b, double c, double d, List<double> roots) {
    if (a.abs() < EPSILON) {
      // Quadratic case, ax^2+bx+c=0
      a = b;
      b = c;
      c = d;
      if (a.abs() < EPSILON) {
        // Linear case, ax+b=0
        a = b;
        b = c;
        // Degenerate case
        if (a.abs() < EPSILON) {
          return 0;
        } else {
          roots[0] = -b / a;
          return 1;
        }
      } else {
        double D = b * b - 4.0 * a * c;
        if (D.abs() < EPSILON) {
          roots[0] = -b / (2.0 * a);
          return 1;
        } else if (D > 0.0) {
          roots[0] = (-b + sqrt(D)) / (2.0 * a);
          roots[1] = (-b - sqrt(D)) / (2.0 * a);
          return 2;
        }
      }
      return 0;
    } else {
      int numRoots = 0;
      // Convert to depressed cubic t^3+pt+q = 0 (subst x = t - b/3a)
      double p = (3.0 * a * c - b * b) / (3.0 * a * a);
      double q = (2.0 * b * b * b - 9.0 * a * b * c + 27.0 * a * a * d) /
          (27.0 * a * a * a);

      if (p.abs() < EPSILON) {
        // p = 0 -> t^3 = -q -> t = -q^1/3
        roots[0] = cubicRoot(-q);
        numRoots = 1;
      } else if (q.abs() < EPSILON) {
        // q = 0 -> t^3 + pt = 0 -> t(t^2+p)=0
        roots[0] = 0.0;
        if (p < 0.0) {
          roots[1] = sqrt(-p);
          roots[2] = -sqrt(-p);
          numRoots = 3;
        } else {
          numRoots = 1;
        }
      } else {
        double D = q * q / 4.0 + p * p * p / 27.0;
        if (D.abs() < EPSILON) {
          // D = 0 -> two roots
          roots[0] = -1.5 * q / p;
          roots[1] = 3.0 * q / p;
          numRoots = 2;
        } else if (D > 0.0) {
          // Only one real root
          double u = cubicRoot(-q / 2.0 - sqrt(D));
          roots[0] = u - p / (3.0 * u);
          numRoots = 1;
        } else {
          // D < 0, three roots, but needs to use complex numbers/trigonometric solution
          double u = 2.0 * sqrt(-p / 3.0);
          double t = acos(3.0 * q / p / u) /
              3.0; // D < 0 implies p < 0 and acos argument in [-1..1]
          double k = 2.0 * pi / 3.0;
          roots[0] = u * cos(t);
          roots[1] = u * cos(t - k);
          roots[2] = u * cos(t - 2.0 * k);
          numRoots = 3;
        }
      }

      // Convert back from depressed cubic
      for (int i = 0; i < numRoots; i++) {
        roots[i] -= b / (3.0 * a);
      }

      return numRoots;
    }
  }

  double get(double x) {
    double p0 = _x0 - x;
    double p1 = _x1 - x;
    double p2 = _x2 - x;
    double p3 = _x3 - x;

    double a = p3 - 3.0 * p2 + 3.0 * p1 - p0;
    double b = 3.0 * p2 - 6.0 * p1 + 3.0 * p0;
    double c = 3.0 * p1 - 3.0 * p0;
    double d = p0;

    List<double> roots = List<double>.filled(3, -1.0);
    int numRoots = solveCubic(a, b, c, d, roots);
    double t = 0.0;
    // Find first valid root.
    for (int i = 0; i < numRoots; i++) {
      double r = roots[i];
      if (r >= 0.0 && r <= 1.0) {
        t = r;
        break;
      }
    }
    return _e * (t * t * t) + _f * (t * t) + _g * t + _h;
  }
}
