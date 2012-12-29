template<unsigned I>class L{enum{v=(L<(I>>13?0:2*I)>::v^L<(I>>13?0:2*I+1)>::v)<<32};};
template<>struct L<0>{enum{v=0};};int main(){return L<1>::v;}
