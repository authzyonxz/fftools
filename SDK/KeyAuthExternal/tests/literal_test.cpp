#include "PublicLiteral.hpp"
#include <cassert>
int main() {
    const auto value=KA_PUBLIC_LITERAL("EXTERNAL");
    assert(value.size()==8);
    assert(value[0]=='E' && value[7]=='L');
    assert(KA_PUBLIC_LITERAL("").empty());
}
