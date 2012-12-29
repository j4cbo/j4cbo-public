template<int I>class L{enum{v=L<I>::q^L<I-1>::s^L<I*2>::r};};int i=L<1>::v;
