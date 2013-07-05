#ifndef clipper_zfill_h_
#define clipper_zfill_h_

#define ZMARK -1;
#include <iostream>
void zfill_mark(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = ZMARK;
}

void zfill_mean(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = (z1 + z2) / 2;
}

void zfill_greater(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z1 > z2 ? z1 : z2;
}

void zfill_lesser(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z1 < z2 ? z1 : z2;
}

void zfill_first(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z1;
}

void zfill_second(long64 z1, long64 z2, IntPoint& pt) {
  pt.Z = z2;
}

// store two 32 bit unsigned ints, stored in one 64 bit int
// if Z is used to hold an index into some other data array
// for each point/edge, this let's us return both indeces
// for the intersection point.
// These indeces would have to be limited to 4,294,967,295 - what fits in a U32 -
// and then any point coming back with a Z > than 4,294,967,295 would obviously
// be an intersection point, and the two indeces could be extracted.
// Should also be able to use this with signed I32 - you would just need
// an extra decoding step to reinterpret the U32 as an I32.

void zfill_both_uint32s(long64 z1, long64 z2, IntPoint& pt) { 

  // Always take the low index if either Z holds a high and a low.
  // The lows should always be the ones relevant to this pt.Z.

  cUInt hi = (cUInt) (z1 & 0xFFFFFFFF);
  cUInt lo = (cUInt) (z2 & 0xFFFFFFFF);
  hi <<= 32;

  // gets cast back to signed integer, but bits should stay the same
  pt.Z = (hi + lo);
}

// The edge order for the z1 and z2 values stored above can be made to
// correspond to edge order in the input and result by swaping the hi and low
// values in these two cases:
// (clip type is NOT intersection or difference) xor (point.Y IS a local extreme)
void zfill_fix_pair_order(IntPoint prevpt, IntPoint thispt, IntPoint nextpt,
  ClipperLib::ClipType ct
  ) {

  if ( 
      //false && 
      thispt.Z > 0xFFFFFFFF) {std::cout << "in fillz\nn";
    if (  (   (   (thispt.Y > prevpt.Y || (thispt.Y == prevpt.Y && thispt.X > prevpt.X)) 
               && (thispt.Y > nextpt.Y || (thispt.Y == nextpt.Y && thispt.X > nextpt.X))
              )
           || (   (thispt.Y < prevpt.Y || (thispt.Y == prevpt.Y && thispt.X < prevpt.X)) 
               && (thispt.Y < nextpt.Y || (thispt.Y == nextpt.Y && thispt.X < nextpt.X))
              ) 
          )
          != // xor
          (ct == ctIntersection || ct == ctDifference)
       ) {
      thispt.Z = ((thispt.Z & 0xFFFFFFFF) << 32) + (thispt.Z >> 32);
    }
  }

}

void zfill_both_uint32s_fix_pairs_polygon(ClipperLib::Polygon& poly,
  ClipperLib::ClipType ct) {

  unsigned int len = poly.size();

  if (len > 2) {

    zfill_fix_pair_order(poly[len - 2], poly[len - 1], poly[0], ct);
    zfill_fix_pair_order(poly[len - 1], poly[0], poly[1], ct);

    for (unsigned int j = 1; j < len - 1; j++) {
      zfill_fix_pair_order(poly[j - 1], poly[j], poly[j + 1], ct);
    }
  }

}

void zfill_both_uint32s_fix_pairs_polygons(ClipperLib::Polygons& polys,
  ClipperLib::ClipType ct) {

  for (unsigned int i = 0; i < polys.size(); i++) {
    
    zfill_both_uint32s_fix_pairs_polygon(polys[i], ct);

  }

}

void zfill_both_uint32s_fix_pairs_polynode(ClipperLib::PolyNode& polynode,
  ClipperLib::ClipType ct) {

  zfill_both_uint32s_fix_pairs_polygon(polynode.Contour, ct);
  for (int i = 0; i < polynode.ChildCount(); ++i) {
    zfill_both_uint32s_fix_pairs_polygon(polynode.Childs[i]->Contour, ct);
    //Add outer polygons contained by (nested within) holes ...
    for (int j = 0; j < polynode.Childs[i]->ChildCount(); ++j) {
      zfill_both_uint32s_fix_pairs_polynode(*polynode.Childs[i]->Childs[j], ct);
    }
  }

}

void zfill_both_uint32s_fix_pairs_polytree(ClipperLib::PolyTree& polytree,
  ClipperLib::ClipType ct) {

  for (int i = 0; i < polytree.ChildCount(); ++i) {
    zfill_both_uint32s_fix_pairs_polynode(*polytree.Childs[i], ct);
  }

}

// interpret the I64 Z values as 32 bit floats, and store both in one 64 bit int
// May lose precision, but you get two for one.
// Should be useful for low-precision data - 23 bit mantissa, 6 to 9 dec. digits

void zfill_both_float32s(long64 z1, long64 z2, IntPoint& pt) { 

  cUInt hi = (cUInt) (float) z1;
  hi <<= 32;
  cUInt lo = (cUInt) (float) z2;

  // back to signed interger, because that's what Clipper expects
  pt.Z = (long64) lo + hi;

}

#endif
