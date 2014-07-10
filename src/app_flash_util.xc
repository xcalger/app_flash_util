/*
 * app_flash_util.xc
 *
 *  Created on: Jun 16, 2014
 *      Author: chrisalger
 */

#include <xs1.h>
#include <platform.h>
#include <flash.h>
#include <stdio.h>
#include <stdlib.h>
#include <syscall.h>
#include <print.h>
#include "SpecMacros.h"
#include "flash_interface.h"


fl_SPIPorts pFlash = {
        PORT_SPI_MISO,
        PORT_SPI_SS,
        PORT_SPI_CLK,
        PORT_SPI_MOSI,
        XS1_CLKBLK_1
};

#define settw(a,b) {__asm__ __volatile__("settw res[%0], %1": : "r" (a) , "r" (b));}
#define setc(a,b) {__asm__  __volatile__("setc res[%0], %1": : "r" (a) , "r" (b));}
#define setclk(a,b) {__asm__ __volatile__("setclk res[%0], %1": : "r" (a) , "r" (b));}
#define portin(a,b) {__asm__  __volatile__("in %0, res[%1]": "=r" (b) : "r" (a));}
#define portout(a,b) {__asm__  __volatile__("out res[%0], %1": : "r" (a) , "r" (b));}


fl_DeviceSpec flash_devices[] = {FL_DEVICE_WINBOND_W25X20};


#if 0
int flash_cmd_enable_ports()
{
    int result = 0;
    setc(p_flash.spiMISO, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiCLK, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiMOSI, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiSS, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiClkblk, XS1_SETC_INUSE_OFF);


    setc(p_flash.spiMISO, XS1_SETC_INUSE_ON);
    setc(p_flash.spiCLK, XS1_SETC_INUSE_ON);
    setc(p_flash.spiMOSI, XS1_SETC_INUSE_ON);
    setc(p_flash.spiSS, XS1_SETC_INUSE_ON);
    setc(p_flash.spiClkblk, XS1_SETC_INUSE_ON);
    setc(p_flash.spiClkblk, XS1_SETC_INUSE_ON);

    setclk(p_flash.spiMISO, XS1_CLKBLK_REF);
    setclk(p_flash.spiCLK, XS1_CLKBLK_REF);
    setclk(p_flash.spiMOSI, XS1_CLKBLK_REF);
    setclk(p_flash.spiSS, XS1_CLKBLK_REF);

    setc(p_flash.spiMISO, XS1_SETC_BUF_BUFFERS);
    setc(p_flash.spiMOSI, XS1_SETC_BUF_BUFFERS);

    settw(p_flash.spiMISO, 8);
    settw(p_flash.spiMOSI, 8);

    if (!result)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}


int flash_cmd_disable_ports()
{
    fl_disconnect();

    setc(p_flash.spiMISO, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiCLK, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiMOSI, XS1_SETC_INUSE_OFF);
    setc(p_flash.spiSS, XS1_SETC_INUSE_OFF);

    return 1;
}
#endif

int main() {

    int rValue, i, bytesChecked, bytesToCheck, flError;
    int fd = 0;
    char filename[32];
    char c,dum;
    int imageNum=0;
    int numInput=0;
    unsigned char *fl_buffer;
    unsigned char *chk_buffer;
    unsigned char file_byte[1];

//    fl_BootImageInfo * restrict p_facImage, p_curImage;


//    p_facImage = &facImage;

    printf("Starting Application\n");
    /* Open a connection to the SPI flash */

//    flash_cmd_enable_ports();
    rValue = fl_connectToDevice(pFlash, flash_devices, 1);
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
        printf("\nMenu:\n");
        printf("(s)elect Image\n");
        printf("(d)isplay selected image information\n");
        printf("(e)rase selected image\n");
        printf("(a)ll upgrade erase\n");
        printf("(p)rogram next image from file\n");
        printf("(v)alidate selected image from file\n");
        printf("e(x)it\n");
        printf("Current Image Selected = %d\n\n",imageNum);
        printf("Command:\n");
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
                    fl_buffer = malloc(fl_getPageSize());
                    chk_buffer = malloc(fl_getPageSize());
                    if((fl_buffer == NULL) || (chk_buffer == NULL))
                    {
                        printf("malloc failed\n");
                    }
                    else{
                        bytesChecked=0;
                        flError=0;
                        i=0;
                        /*init read */
                        if(flash_cmd_read_page(fl_buffer,1))
                        {
                            printf("Error opening to read\n");
                        }
                        else
                        {

                            bytesToCheck=flash_cmd_image_size();
                            rValue=fl_getPageSize();

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
                                        flError++;
                                    }
                                    i++;
                                    bytesChecked++;
                                }
                                printf("Checked %d Bytes\n",bytesChecked);

                            }
                            printf("Check Done\n");
                            printf("%d Errors Found\n",flError);
                            if(bytesChecked<bytesToCheck)
                                {
                                    printf("The file is smaller than image.\n");
                                }

                        }
                    }
                    free(fl_buffer);
                    free(chk_buffer);
                    _close(fd);
                } /* End of if _open */
                break;
        } /* End of switch statement for menu */

    }


    return (0);
}
