#include "KAPolicy.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    unsigned checks=0;
    for (unsigned f=0;f<256;f++) {
        assert(KAPolicyAccept(f,2000,1000,2000,1000)==(f==15)); checks++;
    }
    assert(!KAPolicyAccept(15,1000,1000,2000,1000)); checks++;
    assert(!KAPolicyAccept(15,999,1000,2000,1000)); checks++;
    assert(!KAPolicyAccept(15,2000,1000,1000,1000)); checks++;
    assert(!KAPolicyAccept(15,2000,1000,999,1000)); checks++;
    assert(!KAPolicyAccept(15,2000,0,2000,1000)); checks++;
    assert(!KAPolicyAccept(15,2000,1000,2000,0)); checks++;
    assert(KAPolicyAccept(15,2000,1000,301000,1000)); checks++;
    assert(!KAPolicyAccept(15,2000,1000,301001,1000)); checks++;
    assert(!KAPolicyAccept(15,2000,1000,~0ULL,1000)); checks++;
    printf("Virtualized authorization policy: %u cases passed.\n",checks);
}
