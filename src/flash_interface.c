#include <xs1.h>
#include <flash.h>
#include "flash_interface.h"
#include <flashlib.h>
#include <string.h>
#include <xclib.h>
#include <stdio.h>
#include <print.h>

#ifndef FLASH_MAX_UPGRADE_SIZE
#define FLASH_MAX_UPGRADE_SIZE 128 * 1024 // 128K default
#endif

#define FLASH_ERROR() do {} while(0)

static int flash_device_open = 0;
static fl_BootImageInfo factory_image;
static fl_BootImageInfo select_image;
static int factory_image_valid = 0;
static int max_images = 0;
static int image_selected = 0;

static int upgrade_image_valid = 0;
static int current_flash_subpage_index = 0;
static unsigned char current_flash_page_data[256];



/* Find flash images and print out the information */
int flashOpen(){

    int rValue;
    fl_BootImageInfo facImage, curImage;

    rValue = fl_getFactoryImage(&facImage);
    if(rValue == 0)
    {
        max_images++;
        printf("Factory Image Found\n");
        printf(" Start Address = in decimal: %d\n",facImage.startAddress);
        printf(" Image Size = %d\n",facImage.size);
        printf(" Image Version = %d\n",facImage.version);
        printf(" Factory Image Flag = %d\n",facImage.factory);
        factory_image_valid = 1;
        factory_image = facImage;
        curImage = facImage;

        while(!(fl_getNextBootImage(&curImage))) {
            max_images++;
            printf("Upgrade Image Found\n");
            printf(" Start Address = in decimal: %d\n",curImage.startAddress);
            printf(" Image Size = %d\n",curImage.size);
            printf(" Image Version = %d\n",curImage.version);
            printf(" Factory Image Flag = %d\n",curImage.factory);
        }
        return (0);
    }
    else
    {
        /* return an error if there are no images */
        return (1);
    }

}

int flash_cmd_select_image(int imageNum)
{
    fl_BootImageInfo curImage;
    int i;

    if(factory_image_valid && (imageNum <= max_images))
    {
        if(imageNum == 0)
        {
            select_image=factory_image;
            image_selected = 1;
        }
        else
        {
            for(i=1;i<imageNum;i++)
                fl_getNextBootImage(&curImage);
            select_image = curImage;
            image_selected = 1;
        }
        return (0);
    }
    // Something is wrong with image selection
    return (1);
}

int flash_cmd_print_select_image_info()
{
    if(image_selected)
    {
        printf("Selected Image Info\n");
        printf(" Start Address = in decimal: %d\n",select_image.startAddress);
        printf(" Image Size = %d\n",select_image.size);
        printf(" Image Version = %d\n",select_image.version);
        printf(" Factory Image Flag = %d\n",select_image.factory);
        return(0);
    }
    //no image selected
    return(1);
}


//Need to see if the enable ports is necessary
#if 0
int flash_cmd_init(void)
{
    fl_BootImageInfo image;

    if (!flash_device_open)
    {
        if (flash_cmd_enable_ports())
            flash_device_open = 1;
    }

    if (!flash_device_open)
        return 0;

    // Disable flash protection
    fl_setProtection(0);

    if (fl_getFactoryImage(&image) != 0)
    {
        return 0;
    }

    factory_image = image;

    if (fl_getNextBootImage(&image) == 0)
    {
        upgrade_image_valid = 1;
        upgrade_image = image;
    }

     return 0;
}


int flash_cmd_deinit(void)
{
    if (!flash_device_open)
        return 0;

    flash_cmd_disable_ports();
    flash_device_open = 0;
    return 0;
}
#endif

int flash_cmd_read_page(unsigned char *data)
{
    if (!upgrade_image_valid)
    {
        *(unsigned int *)data = 1;
        return 4;
    }

    if (*(unsigned int *)data == 0)
    {
        fl_startImageRead(&select_image);
    }

    current_flash_subpage_index = 0;

    if (fl_readImageRead(current_flash_page_data) == 0)
    {
        *(unsigned int *)data = 0;
     }
    else
    {
        *(unsigned int *)data = 1;
    }
    return 4;
}

int flash_cmd_read_page_data(unsigned char *data)
{
    unsigned char *page_data_ptr = &current_flash_page_data[current_flash_subpage_index * 64];
    memcpy(data, page_data_ptr, 64);

    current_flash_subpage_index++;

    return 64;
}

static void begin_write()
{
    int result;
    // TODO this will take a long time. To minimise the amount of time spent
    // paused on this operation it would be preferable to move to this to a
    // seperate command, e.g. start_write.
    do
    {
        result = fl_startImageAdd(&factory_image, FLASH_MAX_UPGRADE_SIZE, 0);
    } while (result > 0);

    if (result < 0)
        FLASH_ERROR();
}

static int pages_written = 0;

int flash_cmd_write_page(unsigned char *data)
{
    unsigned int flag = *(unsigned int *)data;

    if (upgrade_image_valid)
    {
        return 0;
    }

    switch (flag)
    {
        case 0:
            // First page.
            begin_write();
            pages_written = 0;
            // fallthrough
        case 1:
            // Do nothing.
            break;
        case 2:
            // Termination.
            if (fl_endWriteImage() != 0)
                FLASH_ERROR();

            // Sanity check
            fl_BootImageInfo image = factory_image;
            if (fl_getNextBootImage(&image) != 0)
                FLASH_ERROR();
            break;
    }
    current_flash_subpage_index = 0;

    return 0;
}

static int isAllOnes(unsigned char page[256])
{
    unsigned i;
    for (i = 0; i < 256; i++)
    {
        if (page[i] != 0xff)
            return 0;
    }
    return 1;
}

int flash_cmd_write_page_data(unsigned char *data)
{
    unsigned char *page_data_ptr = &current_flash_page_data[current_flash_subpage_index * 64];

    if (upgrade_image_valid)
    {
        return 0;
    }

    if (current_flash_subpage_index >= 4)
    {
        return 0;
    }

    memcpy(page_data_ptr, data, 64);

    current_flash_subpage_index++;

    if (current_flash_subpage_index == 4)
    {
        if (isAllOnes(data))
            FLASH_ERROR();
        if (fl_writeImagePage(current_flash_page_data) != 0)
            FLASH_ERROR();
        pages_written++;
    }

    return 0;
}

int flash_cmd_erase_selected_image()
{

    if(image_selected)
    {
        return(fl_deleteImage(&select_image));
    }
    return(1);
}

int flash_cmd_erase_all(void)
{
    fl_BootImageInfo tmp_image = select_image;


    //Needs some work still
    return (1);

    if (upgrade_image_valid)
    {
        if (fl_deleteImage(&select_image) != 0)
        {
            FLASH_ERROR();
        }

        // Keep deleting all upgrade images
        // TODO Perhaps using replace would be nicer...
        while(1)
        {
            if (fl_getNextBootImage(&tmp_image) == 0)
            {
                if (fl_deleteImage(&tmp_image) != 0)
                {
                    FLASH_ERROR();
                }
            }
            else
            {
                break;
            }
        }

    upgrade_image_valid = 0;
    }
    return 0;
}

