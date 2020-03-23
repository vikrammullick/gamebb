import std;
import derelict.sdl2.sdl;

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

int numCyclesPerRefresh = 70224;
const int WIDTH = 160, HEIGHT = 144;

// display pixels on screen
void dispPixels(uint [] pixels, SDL_Surface* windowSurface, SDL_Window *window)
{
	uint rmask = 0xff000000;
	uint gmask = 0x00ff0000;
	uint bmask = 0x0000ff00;
	uint amask = 0x000000ff;
	SDL_Surface* dispSurface = SDL_CreateRGBSurfaceFrom(cast(void *) pixels, 160, 144, 32, 160*4, rmask, gmask, bmask, amask);
	SDL_BlitSurface(dispSurface, null, windowSurface, null);
	SDL_FreeSurface(dispSurface);
	SDL_UpdateWindowSurface(window);
}

void main()
{
   // load boot rom and cartridge into memory
   File boot = File("roms/boot.bin", "r"); 
   File game = File("roms/drmario.gb", "r"); 

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

   memSet(0x00, 0xFF00);

   // init SDL for screen
   DerelictSDL2.load();
	SDL_Init(SDL_INIT_EVERYTHING);
	SDL_Window *window = SDL_CreateWindow( "gamebb", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, WIDTH, HEIGHT, SDL_WINDOW_ALLOW_HIGHDPI );
   SDL_SetWindowResizable(window, SDL_TRUE);
	if (!window)
    {
        writeln("Window creation unsuccessful");
        return;
    }
	SDL_Surface* windowSurface = SDL_GetWindowSurface(window);

   SDL_Event windowEvent;

   uint [160*144] pixels;
	pixels[] = 0xffffffff;

   // run cpu
   for(int i = 0; i < 1000000 || true; i++)
   {
      if (SDL_PollEvent(&windowEvent))
      {
         if (windowEvent.type == SDL_QUIT)
         {
            break;
         }
      }

      int ret = step();      
      if(!ret)
      {
         // if (false)
         break;
      }
      else
      {
         // writef("0b%.2b\n", memGet(0xFF40));
         // writef("0b%.2b\n", memGet(0xFF41));
         // writeln();
         int row = memGet(0xFF44);
         if(row == 154)
         {
            row = 0;
         }
         // write(row*160);
         // write(" ");
         // write(row*160+159);
         // writeln();

         // vram tile data are 8000 to 8fff //4096
         // vram title map is 9800 to  //1024

         if(row <= 143)
         for(int j = 0; j < 20; j++)
         {
            ubyte vramRow = cast(ubyte) (row/8);
            ubyte vramCol = cast(ubyte) j;
            ubyte offset = memGet(0x9800 + vramRow*32+vramCol);
            ubyte realRow = cast(ubyte) (row%8);
            offset += (realRow*2);
            ubyte first = memGet(0x8000 + offset);
            ubyte second = memGet(0x8000 + offset+1);

            

            ubyte [8] colors = [(first & 0b11000000) >> 6,
            (first & 0b00110000) >> 4,
            (first & 0b00001100) >> 2,
            first & 0b00000011,
            (second & 0b11000000) >> 6,
            (second & 0b00110000) >> 4,
            (second & 0b00001100) >> 2,
            second & 0b00000011];

            for(int k = 0; k < 8; k++)
            {
               ubyte col = colors[k];
               switch(col)
               {
                  case 0: 
                     pixels[row*160+j*8+k] = 0xffffffff;
                     break;
                  case 1: 
                     pixels[row*160+j*8+k] = 0x999999ff;
                     break;
                  case 2: 
                     pixels[row*160+j*8+k] = 0x444444ff;
                     break;
                  default: 
                     pixels[row*160+j*8+k] = 0x000000ff;
               }
            }
         }
         dispPixels(pixels, windowSurface, window);
         memSet(cast(ubyte) ++row, 0xFF44);
         if(row==144)
         {
            writeln("drew full frame");
            File frame = File("frame", "wb");
            for(ushort l = 0x8000 ; l <= 0x9FFF; l++)
            {
               frame.rawWrite([memGet(l)]);
            }
            frame.close();

         }
         if(row > 143)
         {
            memSet(((memGet(0xFF41) | (0b00010000)) & (0b11110111)) | (0b00000001), 0xFF41);
                        // writef("0b%.2b\n", memGet(0xFF41));

         }
         else
         {
            memSet((memGet(0xFF41) | (0b00001000)) & (0b11101111) & (0b11111110), 0xFF41);
                        // writef("0b%.2b\n", memGet(0xFF41));

         }

      }
   }

   SDL_FreeSurface(windowSurface);
   SDL_DestroyWindow(window);
   SDL_Quit();
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
      // writef("INST: 0x%.2X\n", inst);
      // writef("INST: 0x%.2X, IO REG: 0x%.2X\n", inst, memGet(0xFF50));
      if(memGet(0xFF50))
      {
         writeln("helloworld");
      }
      switch(inst) { 
         case 0x00: 
            reg.pc++;
            numCycles+=4;
            break;
         case 0x01: 
            reg.pc++;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            numCycles+=12;
            reg.b = high;
            reg.c = low;
            break;
         case 0x04:
            reg.pc++;
            numCycles+=4;
            setH((reg.b & 0b00001111) == 0xFF);
            reg.b++;
            setN(0);
            setZ(!reg.b);
            break;
         case 0x05:
            reg.pc++;
            numCycles+=4;
            setH((reg.b & 0b00001111) >= 1);
            reg.b--;
            setZ(!reg.b);
            setN(1);
            break;
         case 0x06:
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.pc++);
            reg.b = n;
            break;
         case 0x0B:
            reg.pc++;
            numCycles+=8;
            reg.bc--;
            break;
         case 0x0C:
            reg.pc++;
            numCycles+=4;
            setH((reg.c & 0b00001111) == 0xFF);
            reg.c++;
            setN(0);
            setZ(!reg.c);
            break;
         case 0x0D:
            reg.pc++; 
            numCycles+=4;
            setH((reg.c & 0b00001111) >= 1);
            reg.c--;
            setZ(!reg.c);
            setN(1);
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
         case 0x12:
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.de);
            break;
         case 0x13:
            reg.pc++;
            numCycles+=8;
            reg.de++;
            break;
         case 0x15:
            reg.pc++;
            numCycles+=4;
            setH((reg.d & 0b00001111) >= 1);
            reg.d--;
            setZ(!reg.d);
            setN(1);
            break;
         case 0x16:
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.pc++);
            reg.d = n;
            break;
         case 0x17:
            reg.pc++;
            numCycles+=4;
            setN(0);
            setH(0);
            setC(reg.a & (1 << 7));
            int oldC = getC();
            reg.a = cast(ubyte) (reg.a << 1);
            if(oldC)
            {
               reg.a++;
            }
            setZ(!reg.a);
            break;
         case 0x18:
            reg.pc++;
            numCycles+=8;
            byte offset = memGet(reg.pc++);
            reg.pc += offset;
            break; 
         case 0x1A:
            reg.pc++; 
            numCycles+=8;
            reg.a = memGet(reg.de);
            break;
         case 0x1D:
            reg.pc++; 
            numCycles+=4;
            setH((reg.e & 0b00001111) >= 1);
            reg.e--;
            setZ(!reg.e);
            setN(1);
            break;
         case 0x1E:
            reg.pc++; 
            numCycles+=8;
            ubyte nn = memGet(reg.pc++);
            reg.e = nn;
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
         case 0x24:
            reg.pc++;
            numCycles+=4;
            setH((reg.h & 0b00001111) == 0xFF);
            reg.h++;
            setN(0);
            setZ(!reg.h);
            break;
         case 0x28:
            reg.pc++;
            numCycles+=8;
            if(getZ())
            {
               byte offset = memGet(reg.pc++);
               reg.pc += offset;
            }
            else
            {
               reg.pc++;
            }
            break;  
         case 0x2A:
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.hl);
            reg.hl++;
            break;
         case 0x2E:
            reg.pc++; 
            numCycles+=8;
            ubyte nn = memGet(reg.pc++);
            reg.l = nn;
            break;    
         case 0x2F:
            reg.pc++;
            numCycles+=4;
            reg.a = 0b11111111-reg.a;
            setN(1);
            setH(1);
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
         case 0x36:
            reg.pc++;
            numCycles+=12;
            ubyte n = memGet(reg.pc++);
            memSet(n, reg.hl);
            break;
         case 0x3D:
            reg.pc++;
            numCycles+=4;
            setH((reg.a & 0b00001111) >= 1);
            reg.a--;
            setZ(!reg.a);
            setN(1);
            break;
         case 0x3E:
            reg.pc++; 
            numCycles+=8;
            ubyte nn = memGet(reg.pc++);
            reg.a = nn;
            break;
         case 0x47:
            reg.pc++;
            numCycles+=4;
            reg.b = reg.a;
            break;
         case 0x4F:
            reg.pc++;
            numCycles+=4;
            reg.c = reg.a;
            break;
         case 0x57: 
            reg.pc++;
            numCycles+=4;
            reg.d = reg.a;
            break;
         case 0x67: 
            reg.pc++;
            numCycles+=4;
            reg.h = reg.a;
            break;
         case 0x77: 
            reg.pc++;
            numCycles+=8;
            memSet(reg.a, reg.hl);
            break;
         case 0x78: 
            reg.pc++;
            numCycles+=4;
            reg.a = reg.b;
            break;
         case 0x79:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.c;
            break;
         case 0x7B:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.e;
            break;
         case 0x7C:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.h;
            break;
         case 0x7D:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.l;
            break;
         case 0x86:
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.pc++);
            setH(((reg.a & 0b00001111) + (n & 0b00001111)) > 0x0F);
            setC((reg.a + n) > 0xFF);
            setN(0);
            reg.a += n;
            setZ(!reg.a);
            break;
         case 0x90:
            reg.pc++;
            numCycles+=4;
            ubyte n = reg.b;
            setZ(reg.a == n);
            setC(reg.a < n);
            setH((0b00001111 & reg.a) >= (0b00001111 & n));
            setN(1);
            reg.a -= reg.b;
            break;
         case 0xA1:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.a & reg.c;
            setZ(!reg.a);
            setN(0);
            setH(1);
            setC(0);
            break;
         case 0xA9:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.a ^ reg.c;
            setZ(!reg.a);
            setN(0);
            setH(0);
            setC(0);
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
         case 0xB0:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.a | reg.b;
            setZ(!reg.a);
            setN(0);
            setH(0);
            setC(0);
            break;
         case 0xB1:
            reg.pc++;
            numCycles+=4;
            reg.a = reg.a | reg.c;
            setZ(!reg.a);
            setH(0);
            setC(0);
            setN(0);
            break;
         case 0xBE: 
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.hl);
            setZ(reg.a == n);
            setC(reg.a < n);
            setH((0b00001111 & reg.a) >= (0b00001111 & n));
            setN(1);
            break;
         case 0xC1:
            reg.pc++;
            numCycles+=12;
            reg.c = memGet(reg.sp++);
            reg.b = memGet(reg.sp++);
            break;
         case 0xC3:
            reg.pc++;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            numCycles+=12;
            reg.pc1 = high;
            reg.pc2 = low;
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
                  setC(reg.c & (1 << 7));
                  int oldC = getC();
                  reg.c = cast(ubyte) (reg.c << 1);
                  if(oldC)
                  {
                     reg.c++;
                  }
                  setZ(!reg.c);
                  break;
               case 0x37:
                  reg.pc++;
                  numCycles+=8;
                  setZ(!reg.a);
                  setN(0);
                  setH(0);
                  setC(0);
                  ubyte lower = reg.a & 0b00001111;
                  ubyte upper = (reg.a & 0b11110000) >> 4;
                  reg.a = cast(ubyte) ((lower << 4)+upper);
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
         case 0xE6:
            reg.pc++;
            ubyte n = memGet(reg.pc++);
            reg.a = (reg.a) & n;
            setZ(!reg.a);
            setC(0);
            setH(1);
            setN(0);
            break;
         case 0xEA:
            reg.pc++;
            numCycles+=16;
            ubyte low = memGet(reg.pc++);
            ubyte high = memGet(reg.pc++);
            ushort nn = (high << 8) + low;
            memSet(reg.a, nn);
            break;
         case 0xEF:
            reg.pc++;
            numCycles+=32;
            memSet(cast(ubyte) 28, --reg.sp);
            reg.pc = cast(ubyte) 28;
            break;
         case 0xF0:
            reg.pc++;
            numCycles+=12;
            ubyte n = memGet(reg.pc++);
            reg.a = memGet(0xFF00 + n);
            break;
         case 0xFB:
            reg.pc++;
            numCycles+=4;
            //enable interrupts
            break;
         case 0xF3:
            reg.pc++;
            numCycles+=4;
            //disable interrupts
            break;
         case 0xFE:
            reg.pc++;
            numCycles+=8;
            ubyte n = memGet(reg.pc++);
            setZ(reg.a == n);
            setC(reg.a < n);
            setH((0b00001111 & reg.a) >= (0b00001111 & n));
            setN(1);
            break;
         default : 
            writeln(numCycles);
            writeln(memGet(0xFF44));
            writef("Invalid Instruction: 0x%.2X\n", memGet(reg.pc));
            // reg.pc++;
            // numCycles+=4;
            return 0;
      }
      // dispReg();

   }
   return 1;
}

ubyte memGet(ushort i)
{
   if(i < 0x0100)
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