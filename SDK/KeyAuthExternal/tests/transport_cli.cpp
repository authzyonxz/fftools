#include "Transport.hpp"
#include <iostream>
#include <string>
#include <exception>
int main(int argc,char **argv) {
    try {
        std::string token; std::getline(std::cin,token);
        if (argc!=2) return 2;
        if (std::string(argv[1])=="encrypt") {
            std::string json; std::getline(std::cin,json); auto e=keyauth::encrypt(json,token);
            std::cout << e.iv << '\n' << e.ciphertext << '\n' << e.tag << '\n';
        } else {
            keyauth::Envelope e; std::getline(std::cin,e.iv); std::getline(std::cin,e.ciphertext); std::getline(std::cin,e.tag);
            std::cout << keyauth::decrypt(e,token) << '\n';
        }
    } catch(const std::exception&) { std::cerr<<"REJECTED\n";return 1; }
}
