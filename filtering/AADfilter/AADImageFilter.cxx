/*
   Copyright 2016 Antonio Carlos da Silva Senra Filho

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */

#include "itkImageFileWriter.h"
#include "itkImageFileReader.h"
#include "itkAnisotropicAnomalousDiffusionImageFilter.h"
#include "itkRescaleIntensityImageFilter.h"
#include "itkMinimumMaximumImageCalculator.h"
#include "itkCastImageFilter.h"


int main( int argc, char * argv[] )
{
if ( argc < 5 )
        {
          std::cerr << "Missing parameters. " << std::endl;
          std::cerr << "Usage: " << std::endl;
          std::cerr << argv[0]
                    << " inputImageFile outputImageFile Condutance Qvalue NumberOfIteration TimeStep"
                    << std::endl;
          return -1;
        }
    
    typedef    float InputPixelType;
    typedef    float OutputPixelType;

    typedef itk::Image<InputPixelType,  3> InputImageType;
    typedef itk::Image<OutputPixelType, 3> OutputImageType;

    typedef itk::ImageFileReader<InputImageType>                        ReaderType;
    typedef itk::ImageFileWriter<OutputImageType>                       WriterType;
    typedef itk::CastImageFilter<InputImageType, OutputImageType>       CastInput2OutputType;
    typedef itk::RescaleIntensityImageFilter<InputImageType>            RescalerInputFilterType;
    typedef itk::RescaleIntensityImageFilter<OutputImageType>           RescalerOutputFilterType;

    typedef itk::AnisotropicAnomalousDiffusionImageFilter<InputImageType, InputImageType> FilterType;

    typename ReaderType::Pointer reader = ReaderType::New();

    reader->SetFileName( argv[1] );
    reader->Update();

    typename RescalerInputFilterType::Pointer input_rescaler = RescalerInputFilterType::New();
    input_rescaler->SetInput(reader->GetOutput());
    input_rescaler->SetOutputMaximum(255);
    input_rescaler->SetOutputMinimum(0);

    typename FilterType::Pointer filter = FilterType::New();
    filter->SetInput(input_rescaler->GetOutput());
    filter->SetCondutance(std::atof(argv[3]));
    filter->SetIterations(std::atoi(argv[5]));
    filter->SetTimeStep(std::atof(argv[6]));
    filter->SetQ(std::atof(argv[4]));
    filter->Update();

    typename CastInput2OutputType::Pointer cast = CastInput2OutputType::New();
    cast->SetInput( filter->GetOutput() );

    typedef itk::MinimumMaximumImageCalculator<InputImageType> MinMaxCalcType;
    typename MinMaxCalcType::Pointer imgValues = MinMaxCalcType::New();
    imgValues->SetImage(reader->GetOutput());
    imgValues->Compute();

    typename RescalerOutputFilterType::Pointer output_rescaler = RescalerOutputFilterType::New();
    output_rescaler->SetInput(cast->GetOutput());
    output_rescaler->SetOutputMinimum(imgValues->GetMinimum());
    output_rescaler->SetOutputMaximum(imgValues->GetMaximum());
    typename WriterType::Pointer writer = WriterType::New();

    writer->SetFileName( argv[2] );
    writer->SetInput( output_rescaler->GetOutput() );
    writer->SetUseCompression(1);
    writer->Update();

    return EXIT_SUCCESS;
}
