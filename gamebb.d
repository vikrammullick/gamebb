import std;

struct registers {
	struct {
		union {
			struct {
				ubyte f; // z n h c
				ubyte a;
			};
			ushort af;
		};
	};
	
	struct {
		union {
			struct {
				ubyte c;
				ubyte b;
			};
			ushort bc;
		};
	};
	
	struct {
		union {
			struct {
				ubyte e;
				ubyte d;
			};
			ushort de;
		};
	};
	
	struct {
		union {
			struct {
				ubyte l;
				ubyte h;
			};
			ushort hl;
		};
	};
	
	struct {
		union {
			struct {
				ubyte sp2;
				ubyte sp1;
			};
			ushort sp;
		};
	};

   struct {
		union {
			struct {
				ubyte pc2;
				ubyte pc1;
			};
			ushort pc;
		};
	};
} 

registers reg;

ubyte [65536] mem;
ubyte [256] bootmem;

ubyte memGet(ushort i)
{
   if(i <= 0x0100)
   {
      if(mem[0xFF50])
      {
         return mem[i];
      }
      else
      {
         return bootmem[i];
      }
   }
   return mem[i];
}
void memSet(ubyte t, ushort i)
{
   if(i <= 0x0100)
   {
      if(mem[0xFF50])
      {
         mem[i] = t;
      }
      else
      {
         bootmem[i] = t;
      }
   }
   mem[i] = t;
}

int numCyclesPerRefresh = 70224;

int getZ()
{
   return reg.f & (1 << 7);
}
int getN()
{
   return reg.f & (1 << 6);
}
int getH()
{
   return reg.f & (1 << 5);
}
int getC()
{
   return reg.f & (1 << 4);
}
void setZ(int b)
{
   if(b)
   {
      reg.f |= 0b10000000;
   }
   else
   {
      reg.f &= 0b01111111;
   }
}
void setN(int b)
{
   if(b)
   {
      reg.f |= 0b01000000;
   }
   else
   {
      reg.f &= 0b10111111;
   }
}
void setH(int b)
{
   if(b)
   {
      reg.f |= 0b00100000;
   }
   else
   {
      reg.f &= 0b11011111;
   }
}
void setC(int b)
{
   if(b)
   {
      reg.f |= 0b00010000;
   }
   else
   {
      reg.f &= 0b11101111;
   }
}

void main()
{
   File boot = File("roms/boot.bin", "r"); 
   File game = File("roms/tetris.gb", "r"); 

   int ind = 0;
   foreach (ubyte[] buffer; boot.byChunk(1))
   {
      bootmem[ind] = buffer[0];
      ind++;
   }
   boot.close(); 

   ind = 0;
   foreach (ubyte[] buffer; game.byChunk(1))
   {
      mem[ind] = buffer[0];
      ind++;
   }
   game.close(); 


   for(int i = 0; i < 10; i++)
   {
      int ret = step();
      
      if(!ret)
      {
         break;
      }
   }
   
   
}

void dispReg()
{
   writef("A: 0x%.2X, Flags: 0b%.2b, BC: 0x%.4X, DE: 0x%.4X, HL: 0x%.4X, SP: 0x%.4X, PC: 0x%.4X\n", reg.a, reg.f, reg.bc, reg.de, reg.hl, reg.sp, reg.pc);
}

int step()
{
   int numCycles;
   while(numCycles < numCyclesPerRefresh)
   {
      ubyte inst = memGet(reg.pc);
      writef("INST: 0x%.2X\n", inst);
      // writef("INST: 0x%.2X, IO REG: 0x%.2X\n", inst, memGet(0xFF50));
      switch(inst) { 
         case 0x00: 
            reg.pc++;
            numCycles+=4;
            break; 
         case 0x05:
            reg.pc++;
            numCycles+=4;
            if((reg.b & 0b00001111) >= 1)
            {
               setH(1);
            }
            else
            {
               setH(0);
            }
            reg.b--;
            if(reg.b)
            {
               setZ(0);
            }
            else
            {
               setZ(1);
            }
            setN(1);
            break;
         case 0x06:
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.pc++);
            reg.b = n;
            break;
         case 0x0C:
            reg.pc++;
            numCycles+=4;
            if((reg.c & 0b00001111) == 0xFF)
            {
               setH(1);
            }
            else
            {
               setH(0);
            }
            reg.c++;
            setN(0);
            if(reg.c == 0)
            {
               setZ(1);
            }
            else
            {
               setZ(0);
            }
            break;
         case 0x0E:
            reg.pc++; 
            numCycles+=8;
            ubyte nn = memGet(reg.pc++);
            reg.c = nn;
            break;
         case 0x11:
            reg.pc++;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            numCycles+=12;
            reg.d = high;
            reg.e = low;
            break;
         case 0x13:
            reg.pc++;
            numCycles+=8;
            reg.de++;
            break;
         case 0x1A:
            reg.pc++; 
            numCycles+=8;
            reg.a = memGet(reg.de);
            break;
         case 0x17:
            reg.pc++;
            numCycles+=4;
            setN(0);
            setH(0);
            int oldC = getC();
            setC(reg.a & (1 << 7));
            reg.a = cast(ubyte) (reg.a << 1);
            if(oldC)
            {
               reg.a++;
            }
            if(reg.a == 0)
            {
               setZ(1);
            }
            else
            {
               setZ(0);
            }
            break;
         case 0x20:
            reg.pc++;
            numCycles+=8;
            if(!getZ())
            {
               byte offset = memGet(reg.pc++);
               reg.pc += offset;
            }
            else
            {
               reg.pc++;
            }
            break;
         case 0x21:
            reg.pc++;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            numCycles+=12;
            reg.h = high;
            reg.l = low;
            break;
         case 0x22:
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.hl);
            reg.hl++;
            break;
         case 0x23:
            reg.pc++;
            numCycles+=8;
            reg.hl++;
            break;
         case 0x31:
            reg.pc++;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            numCycles+=12;
            reg.sp1 = high;
            reg.sp2 = low;
            break;
         case 0x32:
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.hl);
            reg.hl--;
            break;
         case 0x3E:
            reg.pc++; 
            numCycles+=8;
            ubyte nn = memGet(reg.pc++);
            reg.a = nn;
            break;
         case 0x4F:
            reg.pc++;
            numCycles+=4;
            reg.c = reg.a;
            break;
         case 0x77: 
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.hl);
            break;
         case 0x7B:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.e;
            break;
         case 0xAF:
            reg.pc++;
            numCycles+=4;
            reg.a = 0x00;
            setZ(1);
            setN(0);
            setH(0);
            setC(0);
            break;
         case 0xC1:
            reg.pc++;
            numCycles+=12;
            reg.c = memGet(reg.sp++);
            reg.b = memGet(reg.sp++);
            break;
         case 0xC5:
            reg.pc++;
            numCycles+=16;
            memSet(reg.b, --reg.sp);
            memSet(reg.c, --reg.sp);
            break;
         case 0xC9:
            reg.pc++;
            numCycles+=8;
            ubyte low = memGet(reg.sp++);
            ubyte high = memGet(reg.sp++);
            reg.pc1 = high;
            reg.pc2 = low;
            break;
         case 0xCB:
            reg.pc++;
            switch(memGet(reg.pc)) {
               case 0x11:
                  reg.pc++;
                  numCycles+=8;
                  setN(0);
                  setH(0);
                  int oldC = getC();
                  setC(reg.c & (1 << 7));
                  reg.c = cast(ubyte) (reg.c << 1);
                  if(oldC)
                  {
                     reg.c++;
                  }
                  if(reg.c == 0)
                  {
                     setZ(1);
                  }
                  else
                  {
                     setZ(0);
                  }
                  break;
               case 0x7C:
                  reg.pc++;
                  numCycles+=8;
                  // do actual instruction
                  int isSet = reg.h & (1 << 7);
                  if(isSet)
                  {
                     if(!getZ())
                     {
                        setZ(1);
                     }
                     else
                     {
                        setZ(0);
                     }
                  }
                  setN(0);
                  setH(1);
                  break;
               default: 
                  writef("Invalid Instruction: 0x%.2X\n", memGet(reg.pc));
                  return 0;
            }
            break;
         case 0xCD:
            reg.pc++;
            numCycles+=12;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            memSet(reg.pc1, --reg.sp);
            memSet(reg.pc2, --reg.sp);
            reg.pc1 = high;
            reg.pc2 = low;
            break;
         case 0xE0:
            reg.pc++;
            numCycles+=12;
            ubyte n = memGet(reg.pc++);
            memSet(reg.a, 0xFF00 + n);
            break;
         case 0xE2:
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.c + 0xFF00);
            break;
         case 0xFE:
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.pc++);
            if(reg.a == n)
            {
               setZ(1);
            }
            else
            {
               setZ(0);
            }
            if(reg.a < n)
            {
               setC(1);
            }
            else
            {
               setC(0);
            }
            if((0b00001111 & reg.a) >= (0b00001111 & n))
            {
               setH(1);
            }
            else
            {
               setH(0);
            }

            setN(1);
            break;
         default : 
            writef("Invalid Instruction: 0x%.2X\n", memGet(reg.pc));
            return 0;
      }
      dispReg();
      if(reg.pc == 0)
      {
         return 0;
      }
   }
   return 1;
}