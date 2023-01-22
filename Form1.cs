using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Reflection;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using Dilatation_dll_c;
using System.Threading;

namespace CabanMaciej_JA_proj_Dylatation_cs
{
    public unsafe partial class Form1 : Form
    {
        [DllImport(@"C:\informatyka\JA\CabanMaciej_JA_proj_Dylatation_cs\x64\Debug\JaAsm.dll")]
        //static extern int MyProc1(int sourceHeight, int sourceWidth,int startIndex, int lastIndex, byte* sourcePtr);
        static extern void asmDilatation(byte* sourcePtr, byte* destPtr, long* sourceXYRez, int startIndex, int lastIndex);
        private static Semaphore semaphore1 = new Semaphore(initialCount: 1, maximumCount: 1);
        Bitmap image1;
        public Form1()
        {
            InitializeComponent();
        }

        public unsafe void asmThread2(ref byte[] sourceIm,ref byte[] destinationIm, long[] sourceXYRez, int startIndex, int lastIndex)
        {
            fixed (byte* sourcePtr = &sourceIm[0], destinationPtr = &destinationIm[0])
            {
                fixed (long* sourceXYRez_PTR = &sourceXYRez[0])
                {
                    semaphore1.Release();
                    asmDilatation(sourcePtr, destinationPtr, sourceXYRez_PTR, startIndex, lastIndex);
                }
            }
        }

        public String convertImageToString(Bitmap image)
        {
            String s = "";
            Color white = Color.FromArgb(255, 255, 255, 255);
      
            for (int y = 0; y < image.Height; y++)  
            {
                for (int x = 0; x < image.Width; x++)
                {
                    Color pixelColor = image.GetPixel(x, y);
                    if (pixelColor != white)
                    {
                        s += "1";
                    }
                    else
                    {
                        s += "0";
                    }
                }
            }
            return s;
        } 

        public byte[] convertImageToByteArray(Bitmap image)
        {
            int w = image.Width;
            int h = image.Height;
            byte[] im = new  byte[w*h];
            Color white = Color.FromArgb(255, 255, 255, 255);
            int z = 0;

            for (int y = 0; y < image.Height; y++)
            {
                for (int x = 0; x < image.Width; x++)
                {
                    Color pixelColor = image.GetPixel(x, y);
                    if (pixelColor != white)
                    {
                        im[z] = 1;
                    }
                    else
                    {
                        im[z] = 0;
                    }
                    z++;
                }
            }
            return im;
        }

        public Bitmap convertByteArrayToImage(byte[] b)
        {
            Bitmap image2 = new Bitmap(image1.Width, image1.Height );
            Color white = Color.FromArgb(255, 255, 255, 255);
            Color black = Color.FromArgb(255, 0, 0, 0);

            for (int y = 0; y < image1.Height; y++)
            {
                for (int x = 0; x < image1.Width; x++)
                {
                    if(b[x+(image1.Width * y)]==1)
                    {
                        image2.SetPixel(x, y, black);
                    }
                    else
                    {
                        image2.SetPixel(x, y, white);
                    }
                }
            }
            return image2;
        }


        public int countBlack(Bitmap image)
        {
           int c = 0;
           Color white = Color.FromArgb(255, 255, 255, 255);

           for (int x = 0; x < image.Width ; x++)
           {
              for (int y = 0; y < image.Height ; y++)
              {
                  Color pixelColor = image.GetPixel(x, y);
                  if (pixelColor != white)
                  {
                     c++;
                  }
              }
           }
           return c;
        }

        private void button1_Click(object sender, EventArgs e)
        {
            label2.Text = "";
            //check if path to image is entered
            try
            {
                //Bitmap image1;
                String path = adresBox.Text;
                image1 = new Bitmap(@path, true);

                pictureBox1.Image = image1;
                int c = countBlack(image1);
                
                label7.Text = c.ToString();
            }
            catch (ArgumentException)
            {
                label2.Text = "enter correct path to image";
                return;
            }

            //both are unchecked
            if (radioAsm.Checked==false && radioCs.Checked==false)
            {
                label2.Text = "choose languages";
                return;
            }


            if (radioAsm.Checked)
            {
                //asm   
                try
                {
                    string tn = threadNum.Text;
                    int t = int.Parse(tn);

                    if (t<0 && t>65)
                    {
                        label2.Text = "you need to enter value between 1-64";
                        return;
                    }
                }
                catch(FormatException)
                {
                    label2.Text = "you need to enter value between 1-64";
                    return;
                }

                byte[] sourceIm = convertImageToByteArray(image1);
                byte[] destinationIm = new byte[image1.Height * image1.Width];

                int imageRes = image1.Width * image1.Height;

                long[] sourceXYRes = new long[3];
                sourceXYRes[0] = image1.Width;
                sourceXYRes[1] = image1.Height;
                sourceXYRes[2] = imageRes;

                string tn2 = threadNum.Text;
                int numberOfThreds = int.Parse(tn2); 


                Thread[] threads = new Thread[numberOfThreds];

                int startPixel;
                int lastPixel;

                Stopwatch stopwatch = new Stopwatch();
                stopwatch.Start();

                for (int i =0; i < numberOfThreds; i++)
                {
                    semaphore1.WaitOne();
                    startPixel = (i) * (imageRes / numberOfThreds);
                    lastPixel = (i+1) * (imageRes / numberOfThreds);
                    if (i==(numberOfThreds-1))
                    {
                        lastPixel = imageRes;
                    }
                    threads[i] = new Thread(() => asmThread2(ref sourceIm,ref destinationIm, sourceXYRes, startPixel, lastPixel));
                    threads[i].Start();
                    //Thread.Sleep(10);
                }

                for (int i = 0; i < threads.Length; i++)
                {
                    threads[i].Join();
                }
                stopwatch.Stop();
              
                Bitmap image2 = convertByteArrayToImage(destinationIm);
                beforeLablel.Image = image2;

                int c = countBlack(image2);
                afterLabel.Text = c.ToString();

                //create path to save new bitmap

                String path1 = adresBox.Text;
                String s = "";

                while (path1.EndsWith(".") == false)
                {
                    s = path1[path1.Length - 1] + s;
                    path1 = path1.Remove(path1.Length - 1);
                }
                s = path1[path1.Length - 1] + s;
                path1 = path1.Remove(path1.Length - 1);

                path1 = path1 + "_D" + s;
                image2.Save(path1, System.Drawing.Imaging.ImageFormat.Bmp);
                String time = (stopwatch.ElapsedMilliseconds).ToString();
                timeLabel.Text = time;
            }

            if (radioCs.Checked) 
            {
                //C#
                label2.Text = "you choosed C#";

                String path1 = adresBox.Text;
                Stopwatch stopwatch = new Stopwatch();
                stopwatch.Start();

                Dll_c dll_cs = new Dll_c();
                String s2 = dll_cs.c_dll(path1);

                String time = stopwatch.ElapsedMilliseconds.ToString();
                timeLabel.Text = time;

                label1.Text = s2;

                Bitmap image2 = new Bitmap(s2, true);
                beforeLablel.Image = image2;

                int c = countBlack(image2);
                afterLabel.Text = c.ToString();
            }
        }

        private void label10_Click(object sender, EventArgs e)
        {

        }
    }
}
