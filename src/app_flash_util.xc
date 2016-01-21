/*
 * app_flash_util.xc
 *
 *  Created on: Jun 16, 2014
 *      Author: chrisalger
 */

#include <xs1.h>
#include <platform.h>
#include <stdio.h>
#include <stdlib.h>
#include <syscall.h>
#include <print.h>
#include "SpecMacros.h"
#include "flash_interface.h"

#ifdef QUAD_SPI_FLASH
#include <quadflash.h>
#include <quadflashlib.h>
#else
#include <flash.h>
#include <flashlib.h>
#endif

#ifdef QUAD_SPI_FLASH
fl_QSPIPorts pFlash =
{
    XS1_PORT_1B,
    XS1_PORT_1C,
    XS1_PORT_4B,
    XS1_CLKBLK_5
};
#else
fl_SPIPorts pFlash = {
        PORT_SPI_MISO,
        PORT_SPI_SS,
        PORT_SPI_CLK,
        PORT_SPI_MOSI,
        XS1_CLKBLK_1
};
#endif

void dataFlashMenu(void)
{
    unsigned char data[64];
    int offset,i;
    int rValue, bytesProgrammed, flError;
    int bytes,bytes_to_read;
    int fd = 0;
    char filename[32];
    char c,dum;
    unsigned char *fl_buffer;
    unsigned char *chk_buffer;

    printf("Data Flash Menu\n");
    printf("(p)rint data flash info\n");
    printf("(r)ead and print 64 bytes\n");
    printf("(f)lash data from file\n");
    printf("Command:\n");

    /* Look for command. Extra character is coming from console I believe, so take care of that. */
    scanf("%c%c",&c,&dum);

    switch(c)
    {
    case 'P':
    case 'p':
        printf("Data Partition Size: %d\n",fl_getDataPartitionSize());
        printf("Data Partition Sector 0 Size: %d\n", fl_getDataSectorSize(0));
        printf("Data Partition Page 0 Size: %d\n", fl_getPageSize());
        break;
    case 'R':
    case 'r':
        printf("Enter Offset:\n");
        scanf("%d%c",&offset,&dum);
        if(!fl_readData(offset, 64, data))
        {
            for(i=0;i<64;i++)
            {
                printf("Data[%d]: %d\n",i, data[i]);
            }
        }
        else
        {
            printf("Read Error\n");
        }
        break;
    case 'f':
    case 'F':

        /* To work properly you must specify --boot-partition-size <size> in the xflash command. Having a data partition specified seems optional */
        printf("Enter # bytes to write:\n");
        scanf("%d%c",&bytes,&dum);
      /* fl_getDataPartitionSize() does not appear to work right
        if(fl_getDataPartitionSize() < bytes)
        {
            printf("Error. Data Partition too small.\n");
            return;
        }
        */
        printf("Program data flash. Enter Starting Offset:\n");
        scanf("%d%c",&offset,&dum);

       /*  fl_getDataPartitionSize() does not appear to work right
        if(fl_getDataPartitionSize() < (bytes+offset))
        {
            printf("Error. Data Partition too small.\n");
            return;
        }
        */
        printf("Enter filename of data:\n");
        gets(filename);
        fd = _open(filename, O_RDONLY, 0);

        if (fd == -1) {
          printstrln("Error: _open failed");
        }
        else
        {
            /* File opened. Allocate page buffers for flash and file. */
            if(bytes > fl_getDataSectorSize(0))
            {
                fl_buffer = malloc(fl_getDataSectorSize(0));
                bytes_to_read = fl_getDataSectorSize(0);
            }
            else
            {
                fl_buffer = malloc(bytes);
                bytes_to_read = bytes;
            }

            chk_buffer = malloc(fl_getWriteScratchSize(offset, bytes_to_read));
            if((fl_buffer == NULL) || (chk_buffer == NULL))
            {
                printf("malloc failed\n");
            }
            else{

                /* Read a sector or less of data from the file */
                /* buffers allocated. Begin reading flash a page at a time and check each byte */
                bytesProgrammed=0;
                flError=0;
                i=0;

                    /* Image can be read from flash */
                    while((bytesProgrammed < bytes) && (flError!=1))
                    {
                        rValue = _read(fd, fl_buffer, bytes_to_read);
                        if(fl_writeData(offset, bytes_to_read, fl_buffer, chk_buffer))
                        {
                            /* flash program error */
                            printf("Programming error\n");
                            flError = 1;
                        }
                        else{
                            bytesProgrammed+= bytes_to_read;
                        }
                    }
                    printf("Program Done\n");
                    printf("** %d Errors Found\n",flError);

                free(fl_buffer);
                free(chk_buffer);
            } /* End of if buffers can be allocated */

            _close(fd);
        } /* End of if _open */
        break;
    }
}

int main() {

    int rValue, i, bytesChecked, bytesToCheck, flError;
    int fd = 0;
    char filename[32];
    char c,dum;
    int imageNum=0;
    int numInput=0;
    unsigned char *fl_buffer;
    unsigned char *chk_buffer;



    printf("Starting Application\n");
    /* Open a connection to the SPI flash */

    //rValue = fl_connectToDevice(pFlash, flash_devices, 1);
    rValue = fl_connect(pFlash);
    if(rValue)
    {
        printf("Error - Connecting to device\n");
        return (1);
    }

    /* Report which SPI Flash is connected */
    printf("Connected to Flash\n");
    rValue = fl_getFlashType();
    printf(" FlashType = %d\n",rValue);

    /* Report flash size */
    rValue = fl_getFlashSize();
    printf(" Flash size = %d Bytes\n", rValue);

    /* Report Page Size */
    rValue = fl_getPageSize();
    printf(" page size = %d\n", rValue);

    if(flashOpen())
    {
        printf("No flash images were found\n");
        return (1);
    }
    while (c != 'x')
    {
        /* Generate the menu */
        printf("\nMenu:\n");
        printf("(s)elect Image\n");
        printf("(d)isplay selected image information\n");
        printf("(e)rase selected image\n");
        printf("(a)ll upgrade erase\n");
        printf("(p)rogram next image from file\n");
        printf("(v)alidate selected image from file\n");
        printf("(i)nfo on dataflash partition\n");
        printf("e(x)it\n");
        printf("Current Image Selected = %d\n\n",imageNum);

        printf("Command:\n");

        /* Look for command. Extra character is coming from console I believe, so take care of that. */
        scanf("%c%c",&c,&dum);

        switch(c)
        {
            case 's':
            case 'S':
                printf("Number of Image to select (0 is factory):\n");
                scanf("%d%c",&numInput,&dum);
                printf("\n");
                if(!flash_cmd_select_image(numInput))
                {
                    imageNum = numInput;
                }
                else
                {
                    printf("Invalid Entry\n");
                }
                break;
            case 'd':
            case 'D':
                if(flash_cmd_print_select_image_info())
                {
                   printf("Invalid Entry\n");
                }
                break;
            case 'v':
            case 'V':
                printf("Validate the selected image from file.\n");
                printf("Enter filename:\n");
                gets(filename);
                fd = _open(filename, O_RDONLY, 0);

                if (fd == -1) {
                  printstrln("Error: _open failed");
                }
                else
                {
                    /* File opened. Allocate page buffers for flash and file. */
                    fl_buffer = malloc(fl_getPageSize());
                    chk_buffer = malloc(fl_getPageSize());
                    if((fl_buffer == NULL) || (chk_buffer == NULL))
                    {
                        printf("malloc failed\n");
                    }
                    else{
                        /* buffers allocated. Begin reading flash a page at a time and check each byte */
                        bytesChecked=0;
                        flError=0;
                        i=0;
                        /*This inits the image read only by sending a 1 for init */
                        if(flash_cmd_read_page(fl_buffer,1))
                        {
                            printf("Error opening to read\n");
                        }
                        else
                        {
                            /* Image can be read from flash */
                            bytesToCheck=flash_cmd_image_size();
                            rValue=fl_getPageSize();

                            /* End if end of file or all bytes in image are checked */
                            while((rValue==fl_getPageSize()) && (bytesChecked < bytesToCheck))
                            {

                                if(flash_cmd_read_page(fl_buffer,0))
                                {
                                    printf("Flash Read Error\n");
                                }
                                i=0;
                                rValue = _read(fd, chk_buffer, fl_getPageSize());
                                while((i<rValue) && (bytesChecked < bytesToCheck))
                                {
                                    if(*(chk_buffer+i) != *(fl_buffer+i))
                                    {
                                        /* Collect number of Errors */
                                        flError++;
                                    }
                                    i++;
                                    bytesChecked++;
                                } /* End of bytes checking per page */
                                printf("Checked %d Bytes\n",bytesChecked);

                            }
                            printf("Check Done\n");
                            printf("** %d Errors Found\n",flError);
                            if(bytesChecked < bytesToCheck)
                            {
                                printf("The file is smaller than image.\n");
                            }

                        } /* End of flash image opened for reading */
                        free(fl_buffer);
                        free(chk_buffer);
                    } /* End of if buffers can be allocated */

                    _close(fd);
                } /* End of if _open */
                break; /* End of Validate case choice */

            case 'i':
            case 'I':
                dataFlashMenu();
                break;

            default:
                break;

        } /* End of switch statement for menu */

    } /* End of Menu loop. Exit by user command */


    return (0);
}
