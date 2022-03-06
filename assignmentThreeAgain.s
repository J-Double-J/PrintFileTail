        .text
        .align 2
        .global main

/*struct Node {
    char** string;
    node* nextNode;
};*/

main:
    stp     x19, x30, [sp, -16]!
    str     x25, [sp, -16]!             
    mov     x19, x1                     //Store **argv
    bl      initializeCircleBuffer      //set up circle buffer
    adr     x20, head_ptr               //Set address of the global variable head
    str     x0, [x20]                   //store head in head_ptr
    
    ldr     x1, [x19, 8]!               //grabs the value after ./a.out
    cbz     x1, usageError              //if no file given throw error
    bl      readAndOpenFile             //Opens file passed by argv. File must later be closed; lines found ret in x0
    ldr     x1, [x20]                   //move head ptr to x1
    mov     x25, x0                     //save lines found in safe reg
    bl      printTail                   //print the tail

    ldr     x0, [x20]                   //load head node into x0
    mov     x1, x25                     //store lines found x1
    bl      freeCircleBuffer            //free nodes and strings in nodes

1:  ldr    x25, [sp], 16
    ldp    x19, x30, [sp], 16
    mov    x0,  0
    ret



//node* initializeCircleBuffer();
//mallocs nodes with 32 bytes. First 16 is address to line of chars, next 16 is pointer to next, loops TAILLEN times
initializeCircleBuffer:                 //No params, returns pointer to first node
    str     x30, [sp, -16]!
    mov     x20, xzr                    //counter stored in safe reg
1:  cmp     x20, TAILLEN                //compare counter to how many nodes there needs to be
    beq     3f                          //if equal go to bottom of function
    mov     w0,  16                     //store 16 for malloc
    bl      malloc                      
    cmp     x0, badTailError            //if malloc returns NULL ptr then throw error message
    cmp     x20, xzr                    //if first node
    beq     2f                          //special case branch
    str     x0,  [x21, 8]               //store the new node as previousNode's *nextNode
    str     xzr, [x0]                   //store 0 for char* string initiliazer
    mov     x21, x0                     //store pointer of current node in x21. x21 will be "previousNode"
    add     x20, x20, 1                 //increment counter
    b       1b                          //loop
    
2:  mov     x21, x0                     //Assign previousNode
    mov     x22, x0                     //Save head node for when we reach TAILLEN'th node
    str     xzr, [x0]                   //set *string to NULL
    add     x20, x20, 1                 //increment counter
    b       1b                          //go back to loop

3:  str     x22, [x21, 8]               //TAILLEN'th node will point to headnode
    mov     x0, x22                     //move *headNode to x0 to be returned
    ldr     x30, [sp], 16
    ret                                 //ret headNode



//int readAndOpenFile(node* head, string file)
//The primary function of the program. In charge of opening and closing the file the user gives.
//Additionally calls another function storeString that begins filling the circle buffer with characters
readAndOpenFile: //params: x0 - [head_ptr]; x1 - file name
    str     x30, [sp, -16]!
    mov     x29, xzr                    //bool end of file is false
    mov     x23, xzr                    //store current buffer position to be written to in safe reg. Has to be x because of sign
    mov     x19, x0                     //store head in safe register (**argv no longer needs the reg)
    mov     w24, wzr                    //How many lines have been found so far
    mov     w25, wzr                    //nextNodeToStore is zero'd out
    mov     x0, x1                      //move file name to x0
    mov     x1, xzr                     //set flag O_RDONLY
    bl      open                        //open(path, O_RDONLY);
    cmp     w0, -1                      //if open returned -1
    beq     badOpenError                //then throw bad open error msg
    mov     x21, x0                     //move file descriptor to x21
    mov     x0, BUFFERSIZE              //move buffer size to x0
    bl      malloc
    cbz     x0, noLineError             //if malloc returns NULL then throw no line error
    mov     x22, x0                     //save buffer in safe reg

//reset line buffer, read in one character, determine any special cases, else loop
mrs:mov     x0, x22                     //move buffer to x0 (mrs - memory reset)
    mov     w1, wzr                     //move 0 to w1, tell memset what to set values to
    mov     x2, BUFFERSIZE              //move buffer size to w2
    bl      memset                      //memset(bufferString,0,4096);
    mov     x22, x0
1:  add     x1, x22, x23                //load buffer offset by x23 bytes to x1
    mov     x0, x21                     //move file descriptor to x0
    mov     x2, 1                       //move 1 char into buffer         
    bl      read                        //read(fd, buffer[], 1)
    cbz     x0, 5f                      //if end of file 
    ldrb    w0, [x22, x23]              //take x23'th byte in the buffer
    cbz     w0, 2f                      //if char is NUL char, branch
    cmp     w0, 10                      //if char is new line
    beq     3f                          //branch if true
    cmp     x23, 4094                   //if buffer progress is 4094 or greater (nearly full)
    bge     4f                          //branch if true
    add     x23, x23, 1                 //increment buffer progress
    b       1b                          //else loop

//if null terminator found, ensure there is a new line before it
2:  sub     x5, x23, 1                  //subtract one off of counter 
    ldr     x0, [x22, x5]               //load the x5'th (x23'th-1) value in the buffer     TOOD: MAY BE WRONG?
    cmp     x0, 10                      //if new line
    beq     7f                          //go ahead and alloc
    mov     w6, 10                      //move newline into w6
    str     w6, [x22, x5]               //store new line
    //add     x23, x23, 1               //increment buffer pos
    str     xzr,[x22, x23]              //store null terminator after new line
    b       7f                          //malloc and store branch
                              


//if newline char found, after no null term was found
3:  add     x23, x23, 1                 //increment x23 by 1 to get access to next position in buffer
    str     xzr, [x22, x23]             //store null in the buffer at x23'th position
7:  mov     x0, x23                     //move the counter to x0
    bl      malloc                      //allocate char[] of x23'th size
    cbz     x0, badAllocError           //if malloc returns NULL throw bad alloc error and exit
    mov     w5, wzr                     //counter
    mov     x10, x22
80: cmp     w5, w23                     //if counter == size of buffer
    beq     81f
    ldrb    w7, [x10, x5]
    strb    w7, [x0, x5]                //store one character from x22 buffer into perfect sized memory. 
    //mov     w6, 1
    add     w5, w5, 1                  //increment counter
    //add     x10, x22, x6                //increment memory
    b       80b

81: mov     x1, x19                     //move head_ptr to x1
    mov     w2, w25                     //move which node to store in to w2
    bl      storeString                 //store the string in the circle buffer  
    //add     w24, w24, 1                 //increment linesFound



    add     w25, w25, 1                 //increment which node to store into
    cmp     w25, 10                     //if the next node is 10
    bne     4f                          //if they aren't equal skip ahead
    mov     w25, wzr                    //else zero out which node is next (circle back to head)
4:  add     x24, x24, 1                 //increment lines found
    mov     x23, xzr                    //rezero out buffer progress
    cmp     x29, xzr                    //if not end of file
    beq     mrs                         //loop to clear buffer
    b       6f                          //else end func

//TODO: test what happens when new line at bottom of the file
//if end of file implement any 
5:  cbnz    x23, 51f                    //if x23 is not 0
    ldrb    w5, [x22]                   //and if current buffer value at the beginning is 0
    cbz     w5, 6f                      //free node and dont add line
51: mov     w5, 10                      //move value 10 (new line) to w5 
    str     w5, [x22, x23]              //insert new line in buffer
    add     x23, x23, 1                 //increment x23
    str     xzr,[x22,x23]               //store NUL in new buffer pos
    mov     x29, 1                      //bool end of file set true
    b       7b                          //store line in node
    

6:  cmp     x22, xzr                    //if buffer is free'd already. This would be if it finds empty line at end of file, after x22 was already empty.
    beq     7f
    mov     x0, x22                     //move buffer to x0
    bl      free                        //free buffer
7:  cmp     w24, 10                     //if lines found is less than or equal to 10
    ble     8f                          //end func
    mov     w24, 10                     //else set lines found to 10                                
8:  mov     x0, x21                     //move file descriptor
    bl      close                       //close file
    mov     w0, w24
    ldr     x30, [sp], 16               
    ret                                 //return lines found


//void storeString(char* string, node* head, short int pos);
//Go through nodes until we get to the right one then store the string 
storeString:                            //params: x0 - char**, x1 - [head_ptr], w2 - node pointed to
    str     x30, [sp, -16]!
    //ldr     x4, [x0]                    //get char*
    //mov     x0, x4
    //bl      puts

    mov     w3, wzr                     //current node pos
1:  cmp     w3, w2                      //compare current node pos to node pointed at
    beq     2f                          //if equal break and continue
    ldr     x1, [x1, 8]                 //current node is next node
    ldr     w5, [x1]                    //TODO delete
    add     w3, w3, 1                   //increment current node pos
    b       1b

//TODO: ????
2:  ldr     x28, [x1, 8]
    str     x0, [x1]                    //store char** into the current node
    ldr     x28, [x1, 8]                //TODO: DELETE
    //TODO: delete
    /*ldr     x0, [x1]                    //test statements, prints out all the lines of the file
    ldr     x0, [x0]
    bl      puts
    mov     x0, xzr
    ldr     x0, [x28]
    cbz     x0, 3f
    ldr     x0, [x0]
    //bl      put*/

3:
    ldr     x30, [sp], 16
    ret                                 //no ret val


//void printTail(int linesStored, node* head);
//Loops through the head linesStored times printing the strings found at the end of the file
printTail:                              //params: x0 - linesStored, x1 - [head_ptr] 
    str     x30, [sp, -16]!
    mov     w28, wzr                    //zero out currentNodePos
    sub     x26, x0, 1                  //turn lines stored into linesStoredPos, -1 means no lines were stored, move to 26
    mov     x27, x1                     //store current node in x27
    cmp     x26, -1                     //if linesStoredPos equals -1
    beq     2f                          //then end func
1:  cmp     x28, x26                    //if current node pos is greater than lines stored pos
    bgt     2f                          //then end func
    ldr     x1, [x27]                   //load char** into x1
    //ldr     x1, [x1]                    //load char*
    adr     x0, tailString              //move address of .asciz text into x0
    bl      printf                      //print string
    add     w28, w28, 1                 //increment current node pos
    ldr     x27, [x27, 8]               //store next node
    b       1b                          //loop

2:  ldr     x30, [sp], 16
    ret                                 //no ret val
    


//void freeCircleBuffer(node* head, short int numLines);
//Go through buffer and free every node. For every node pos check if less or eq to numOfLines found, and free char* string inside if true
//This function is last to be called so all "safe" registers are free to use
freeCircleBuffer:                       //params: x0 - headnode; x1 - numLines <- count does not start at 0

    str     x30, [sp, -16]!
    mov     x20, 0                      //counter
    mov     x21, x0                     //currentNode
    mov     x22, x1                     //numLines
    sub     x22, x22, 1                 //decrement numLines so count is now last line will be found at node #. -1 means no lines, 9 all nodes
1:  cmp     x20, TAILLEN                //if TAILLEN nodes are freed
    beq     4f                          //end func
    cmp     x20, x22                    //if counter is less than or equal to numLines
    ble     3f                          //branch and free char* string
2:  mov     x0,  x21                    //move current node to x0 to be freed                  
    ldr     x21, [x21,8]                //current node is now currentnode's *nextNode
    bl      free
    add     x20, x20, 1                 //increment counter
    b       1b                          //loop

//frees char* string then returns to loop to free node
3:  ldr     x0, [x21]                   //load char* object to free
    bl      free
    //mov     x0, x23                      //load char** to be free
    //bl      free
    b       2b                          //go back to free node

4:  ldr     x30, [sp], 16           
    ret                                 //returns nothing



/******************ERROR THROWS******************/
//ALL FUNCTIONS THROW RELEVANT ERROR THEN ENDS PROGRAM
//NO PARAMS OR RETURNS

//void usageError()
usageError:
    str     x30, [sp, -16]!     
    adr     x0,  usage      //store address of .data usage error
    bl      printf          //print
    ldr     x30, [sp], 16
    mov     x0, xzr
    bl      exit

//void badOpenError()
badOpenError:
    str     x30, [sp, -16]!     
    adr     x0,  badopen    //store address of .data badopen error
    bl      perror          //throw badopen error msg plus description why it didn't work
    ldr     x30, [sp], 16
    mov     x0, xzr
    bl      exit

//void noLineError()
noLineError:
    str     x30, [sp, -16]!     
    adr     x0,  noline     //store address of .data noline error
    bl      printf          //print
    ldr     x30, [sp], 16
    mov     x0, xzr
    bl      exit

//void badTailError()
badTailError:
    str     x30, [sp, -16]!     
    adr     x0,  badtail    //store address of .data usage error
    bl      printf          //print
    ldr     x30, [sp], 16
    mov     x0, xzr
    bl      exit

//void badAllocError()
badAllocError:
    str     x30, [sp, -16]!     
    adr     x0,  badalloc   //store address of .data usage error
    bl      printf          //print
    ldr     x30, [sp], 16
    mov     x0, xzr
    bl      exit



    .data
.EQU        TAILLEN, 10
.EQU        BUFFERSIZE, 4096
head_ptr:   .space   8    
usage:		.asciz	"File name must be given."
badopen:	.asciz	"Open file failed"
noline:		.asciz	"Allocating line buffer failed."
badtail:	.asciz	"Allocating tail pointer buffer failed."
badalloc:	.asciz	"Allocating a tail line failed."
tailString: .asciz  "%s"
    .end


//it's becoming increasingly clear that I am writing non-standard code with constantly using safe registers
