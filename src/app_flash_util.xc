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

    int rValue;

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

    if(flashOpen())
    {
        return (1);
    }
    return (0);
}
